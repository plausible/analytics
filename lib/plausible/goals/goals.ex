defmodule Plausible.Goals do
  use Plausible
  use Plausible.Repo
  use Plausible.Funnel.Const

  import Ecto.Query

  alias Plausible.Goal
  alias Ecto.Multi
  alias Ecto.Changeset

  @max_goals_per_site 1_000
  @spec max_goals_per_site(Keyword.t()) :: pos_integer()
  def max_goals_per_site(opts \\ []) do
    override = Keyword.get(opts, :max_goals_per_site)

    if override do
      override
    else
      # see: config/test.exs - you can steer this limit for tests
      # by providing `max_goals_per_site` option to e.g. create/3
      Application.get_env(:plausible, :max_goals_per_site, @max_goals_per_site)
    end
  end

  @spec get(Plausible.Site.t(), pos_integer()) :: nil | Plausible.Goal.t()
  def get(site, id) when is_integer(id) do
    q =
      from g in Plausible.Goal,
        where: g.site_id == ^site.id,
        order_by: [desc: g.id],
        where: g.id == ^id

    Repo.one(q)
  end

  @spec create(Plausible.Site.t(), map(), Keyword.t()) ::
          {:ok, Goal.t()}
          | {:error, Changeset.t()}
          | {:error, :upgrade_required}
          | {:error, :revenue_goals_unavailable}
  @doc """
  Creates a Goal for a site.

  If the created goal is a revenue goal, it sets site.updated_at to be
  refreshed by the sites cache, as revenue goals are used during ingestion.

  Returns `{:ok, goal}` or `{:error, changeset}` when creation fails due to
  invalid fields. It can also return:

  * `{:error, :upgrade_required}` - Adding a revenue goal is not allowed
    for team's subscription.

  * `{:error, :revenue_goals_unavailable}` - When the site is a consolidated
    view and the goal created is a revenue goal. Revenue goal creation is not
    allowed for consolidated views due to the inability to force a single
    currency on a goal across all consolidated sites.
  """
  def create(site, params, opts \\ []) do
    Repo.transaction(fn ->
      case insert_goal(site, params, opts) do
        {:ok, :insert, goal} ->
          on_ee do
            now = Keyword.get(opts, :now, DateTime.utc_now())
            # credo:disable-for-next-line Credo.Check.Refactor.Nesting
            if Plausible.Goal.Revenue.revenue?(goal) do
              Plausible.Site.Cache.touch_site!(site, now)
            end
          end

          Repo.preload(goal, :site)

        {:ok, :upsert, goal} ->
          Repo.preload(goal, :site)

        {:error, cause} ->
          Repo.rollback(cause)
      end
    end)
  end

  @spec update(Plausible.Goal.t(), map()) ::
          {:ok, Goal.t()} | {:error, Changeset.t()} | {:error, :upgrade_required}
  def update(goal, params) do
    changeset = Goal.changeset(goal, params)

    Repo.transaction(fn ->
      site = Repo.preload(goal, :site).site

      with :ok <- maybe_check_feature_access(site, changeset),
           {:ok, updated_goal} <- Repo.update(changeset),
           :ok <- Plausible.Segments.update_goal_in_segments(site, goal, updated_goal) do
        on_ee do
          Repo.preload(updated_goal, :funnels)
        else
          updated_goal
        end
      else
        {:error, %Changeset{} = changeset} ->
          Repo.rollback(changeset)

        {:error, :upgrade_required} ->
          Repo.rollback(:upgrade_required)
      end
    end)
  end

  def find_or_create(site, params, opts \\ [])

  def find_or_create(
        site,
        %{
          "goal_type" => "event",
          "event_name" => event_name,
          "currency" => currency
        } = params,
        opts
      )
      when is_binary(event_name) and is_binary(currency) do
    with {:ok, goal} <- create(site, params, do_upsert(opts)) do
      if to_string(goal.currency) == currency do
        {:ok, goal}
      else
        # we must disallow creation of the same goal name with different currency
        changeset =
          goal
          |> Goal.changeset()
          |> Changeset.add_error(
            :event_name,
            "'#{goal.event_name}' (with currency: #{goal.currency}) has already been taken"
          )

        {:error, changeset}
      end
    end
  end

  def find_or_create(site, %{"goal_type" => "event", "event_name" => event_name} = params, opts)
      when is_binary(event_name) do
    create(site, params, do_upsert(opts))
  end

  def find_or_create(_, %{"goal_type" => "event"}, _), do: {:missing, "event_name"}

  def find_or_create(site, %{"goal_type" => "page", "page_path" => _} = params, opts) do
    create(site, params, do_upsert(opts))
  end

  def find_or_create(_, %{"goal_type" => "page"}, _), do: {:missing, "page_path"}

  def list_revenue_goals(site) do
    from(g in Plausible.Goal,
      where: g.site_id == ^site.id and not is_nil(g.currency),
      select: %{display_name: g.display_name, currency: g.currency},
      order_by: [desc: g.id],
      limit: ^max_goals_per_site()
    )
    |> Plausible.Repo.all()
  end

  def for_site(site, opts \\ []) do
    site
    |> for_site_query(opts)
    |> Repo.all()
    |> Enum.map(&maybe_trim/1)
  end

  def for_site_query(site \\ nil, opts \\ []) do
    query =
      from g in Goal,
        order_by: [desc: g.id],
        limit: ^max_goals_per_site(opts)

    query =
      if site do
        from g in query,
          inner_join: assoc(g, :site),
          where: g.site_id == ^site.id,
          preload: [:site]
      else
        query
      end

    query =
      if Keyword.get(opts, :include_goals_with_custom_props?, true) == false do
        from g in query, where: g.custom_props == ^%{}
      else
        query
      end

    if ee?() and opts[:preload_funnels?] == true do
      from(g in query,
        left_join: assoc(g, :funnels),
        group_by: g.id,
        preload: [:funnels]
      )
    else
      query
    end
  end

  def batch_create_event_goals(names, site, opts \\ []) do
    Enum.reduce(names, [], fn name, acc ->
      case insert_goal(site, %{event_name: name}, do_upsert(opts)) do
        {:ok, _, goal} -> acc ++ [goal]
        _ -> acc
      end
    end)
  end

  @doc """
  If a goal belongs to funnel(s), we need to inspect their number of steps.

  If it exceeds the minimum allowed (defined via `Plausible.Funnel.min_steps/0`),
  the funnel will be reduced (i.e. a step associated with the goal to be deleted
  is removed), so that the minimum number of steps is preserved. This is done
  implicitly, by postgres, as per on_delete: :delete_all.

  Otherwise, for associated funnel(s) consisting of minimum number steps only,
  funnel record(s) are removed completely along with the targeted goal.
  """
  def delete(id, %Plausible.Site{id: site_id}) do
    delete(id, site_id)
  end

  def delete(id, site_id) do
    goal_query =
      from(g in Goal,
        where: g.id == ^id,
        where: g.site_id == ^site_id
      )

    goal_query = on_ee(do: preload(goal_query, funnels: :steps), else: goal_query)

    result =
      Multi.new()
      |> Multi.one(
        :goal,
        goal_query
      )
      |> Multi.run(:funnel_ids_to_wipe, fn
        _, %{goal: nil} ->
          {:error, :not_found}

        _, %{goal: %{funnels: []}} ->
          {:ok, []}

        _, %{goal: %{funnels: funnels}} ->
          funnels_to_wipe =
            funnels
            |> Enum.filter(&(Enum.count(&1.steps) == Funnel.Const.min_steps()))
            |> Enum.map(& &1.id)

          {:ok, funnels_to_wipe}
      end)
      |> Multi.merge(fn
        %{funnel_ids_to_wipe: []} ->
          Ecto.Multi.new()

        %{funnel_ids_to_wipe: [_ | _] = funnel_ids} ->
          Ecto.Multi.new()
          |> Multi.delete_all(
            :delete_funnels,
            from(f in "funnels",
              where: f.id in ^funnel_ids
            )
          )
      end)
      |> Multi.delete_all(
        :delete_goals,
        fn _ ->
          from g in Goal,
            where: g.id == ^id,
            where: g.site_id == ^site_id
        end
      )
      |> Repo.transaction()

    case result do
      {:ok, _} -> :ok
      {:error, _step, reason, _context} -> {:error, reason}
    end
  end

  @spec count(Plausible.Site.t()) :: non_neg_integer()
  def count(site) do
    Repo.aggregate(
      from(
        g in Goal,
        where: g.site_id == ^site.id
      ),
      :count
    )
  end

  @spec create_outbound_links(Plausible.Site.t()) :: :ok
  def create_outbound_links(%Plausible.Site{} = site) do
    create(site, %{"event_name" => "Outbound Link: Click"}, do_upsert())
    :ok
  end

  @spec create_file_downloads(Plausible.Site.t()) :: :ok
  def create_file_downloads(%Plausible.Site{} = site) do
    create(site, %{"event_name" => "File Download"}, do_upsert())
    :ok
  end

  @spec create_form_submissions(Plausible.Site.t()) :: :ok
  def create_form_submissions(%Plausible.Site{} = site) do
    create(site, %{"event_name" => "Form: Submission"}, do_upsert())
    :ok
  end

  @spec create_404(Plausible.Site.t()) :: :ok
  def create_404(%Plausible.Site{} = site) do
    create(site, %{"event_name" => "404"}, do_upsert())
    :ok
  end

  @spec delete_outbound_links(Plausible.Site.t()) :: :ok
  def delete_outbound_links(%Plausible.Site{} = site) do
    q =
      from g in Goal,
        where: g.site_id == ^site.id,
        where: g.event_name == "Outbound Link: Click"

    Repo.delete_all(q)
    :ok
  end

  @spec delete_file_downloads(Plausible.Site.t()) :: :ok
  def delete_file_downloads(%Plausible.Site{} = site) do
    q =
      from g in Goal,
        where: g.site_id == ^site.id,
        where: g.event_name == "File Download"

    Repo.delete_all(q)
    :ok
  end

  @spec delete_404(Plausible.Site.t()) :: :ok
  def delete_404(%Plausible.Site{} = site) do
    q =
      from g in Goal,
        where: g.site_id == ^site.id,
        where: g.event_name == "404"

    Repo.delete_all(q)
    :ok
  end

  @spec delete_form_submissions(Plausible.Site.t()) :: :ok
  def delete_form_submissions(%Plausible.Site{} = site) do
    q =
      from g in Goal,
        where: g.site_id == ^site.id,
        where: g.event_name == "Form: Submission"

    Repo.delete_all(q)
    :ok
  end

  defp insert_goal(site, params, opts) do
    params = Map.delete(params, "site_id")

    insert_opts =
      if upsert?(opts) do
        [on_conflict: :nothing]
      else
        []
      end

    changeset = Goal.changeset(%Goal{site_id: site.id}, params)

    with :ok <- maybe_check_feature_access(site, changeset),
         :ok <- check_no_currency_if_consolidated(site, changeset),
         :ok <- check_goals_limit(site, changeset, opts),
         {:ok, goal} <- Repo.insert(changeset, insert_opts) do
      # Upsert with `on_conflict: :nothing` strategy
      # will result in goal struct missing primary key field
      # which is generated by the database.
      if goal.id do
        {:ok, :insert, goal}
      else
        get_params =
          goal
          |> Map.take([:site_id, :event_name, :page_path])
          |> Enum.reject(fn {_, value} -> is_nil(value) end)

        {:ok, :upsert, Repo.get_by!(Goal, get_params)}
      end
    end
  end

  defp maybe_check_feature_access(site, changeset) do
    with :ok <- revenue_goals_access_check(site, changeset) do
      custom_props_goals_access_check(site, changeset)
    end
  end

  defp revenue_goals_access_check(site, changeset) do
    if Changeset.get_field(changeset, :currency) do
      site = Plausible.Repo.preload(site, :team)
      Plausible.Billing.Feature.RevenueGoals.check_availability(site.team)
    else
      :ok
    end
  end

  defp custom_props_goals_access_check(site, changeset) do
    if map_size(Changeset.get_field(changeset, :custom_props)) > 0 do
      site = Plausible.Repo.preload(site, :team)
      Plausible.Billing.Feature.Props.check_availability(site.team)
    else
      :ok
    end
  end

  defp check_goals_limit(site, changeset, opts) do
    if upsert?(opts) and goal_exists_for_upsert?(site, changeset) do
      :ok
    else
      if count(site) >= max_goals_per_site(opts) and changeset.valid? do
        changeset
        |> Changeset.add_error(:page_path, "Maximum number of goals reached")
        |> Changeset.add_error(:event_name, "Maximum number of goals reached")
        |> Changeset.apply_action(:insert)
      else
        :ok
      end
    end
  end

  defp check_no_currency_if_consolidated(site, changeset) do
    if Plausible.Sites.consolidated?(site) && Changeset.get_field(changeset, :currency) do
      {:error, :revenue_goals_unavailable}
    else
      :ok
    end
  end

  defp maybe_trim(%Goal{} = goal) do
    # we make sure that even if we saved goals erroneously with trailing
    # space, it's removed during fetch
    goal
    |> Map.update!(:event_name, &maybe_trim/1)
    |> Map.update!(:page_path, &maybe_trim/1)
  end

  defp maybe_trim(s) when is_binary(s) do
    String.trim(s)
  end

  defp maybe_trim(other) do
    other
  end

  defp upsert?(opts) do
    Keyword.get(opts, :upsert?, false)
  end

  defp do_upsert(opts \\ []) do
    Keyword.put(opts, :upsert?, true)
  end

  defp goal_exists_for_upsert?(site, changeset) do
    event_name = Changeset.get_field(changeset, :event_name)
    page_path = Changeset.get_field(changeset, :page_path)
    scroll_threshold = Changeset.get_field(changeset, :scroll_threshold)

    query_params =
      [site_id: site.id]
      |> maybe_add_filter(:event_name, event_name)
      |> maybe_add_filter(:page_path, page_path)
      |> maybe_add_filter(:scroll_threshold, scroll_threshold)

    Repo.exists?(from(g in Goal, where: ^query_params))
  end

  defp maybe_add_filter(params, _key, nil), do: params
  defp maybe_add_filter(params, key, value), do: Keyword.put(params, key, value)
end
