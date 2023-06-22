defmodule Plausible.Goals do
  use Plausible.Repo
  alias Plausible.Goal
  alias Ecto.Multi

  use Plausible.Funnel

  @doc """
  Creates a Goal for a site.

  If the created goal is a revenue goal, it sets site.updated_at to be
  refreshed by the sites cache, as revenue goals are used during ingestion.
  """
  def create(site, params, now \\ DateTime.utc_now()) do
    params = Map.merge(params, %{"site_id" => site.id})

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:goal, Goal.changeset(%Goal{}, params))
    |> Ecto.Multi.run(:site, fn repo, %{goal: goal} ->
      if Goal.revenue?(goal) do
        now =
          now
          |> DateTime.truncate(:second)
          |> DateTime.to_naive()

        site
        |> Ecto.Changeset.change(updated_at: now)
        |> repo.update()
      else
        {:ok, site}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{goal: goal}} -> {:ok, Repo.preload(goal, :site)}
      {:error, _failed_operation, failed_value, _changes_so_far} -> {:error, failed_value}
    end
  end

  def find_or_create(site, %{"goal_type" => "event", "event_name" => event_name}) do
    query =
      from g in Goal,
        inner_join: assoc(g, :site),
        where: g.site_id == ^site.id,
        where: g.event_name == ^event_name,
        preload: [:site]

    goal = Repo.one(query)

    case goal do
      nil -> create(site, %{"event_name" => event_name})
      goal -> {:ok, goal}
    end
  end

  def find_or_create(_, %{"goal_type" => "event"}), do: {:missing, "event_name"}

  def find_or_create(site, %{"goal_type" => "page", "page_path" => page_path}) do
    query =
      from g in Goal,
        inner_join: assoc(g, :site),
        where: g.site_id == ^site.id,
        where: g.page_path == ^page_path,
        preload: [:site]

    goal = Repo.one(query)

    case goal do
      nil -> create(site, %{"page_path" => page_path})
      goal -> {:ok, goal}
    end
  end

  def find_or_create(_, %{"goal_type" => "page"}), do: {:missing, "page_path"}

  def for_site(site, opts \\ []) do
    query =
      from g in Goal,
        inner_join: assoc(g, :site),
        where: g.site_id == ^site.id,
        order_by: [desc: g.id],
        preload: [:site]

    query =
      if opts[:preload_funnels?] do
        from g in query,
          left_join: assoc(g, :funnels),
          group_by: g.id,
          preload: [:funnels]
      else
        query
      end

    query =
      if opts[:preload_funnels?] do
        from(g in query,
          left_join: assoc(g, :funnels),
          group_by: g.id,
          preload: [:funnels]
        )
      else
        query
      end

    query
    |> Repo.all()
    |> Enum.map(&maybe_trim/1)
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
  def delete(id, site) do
    result =
      Multi.new()
      |> Multi.one(
        :goal,
        from(g in Goal,
          where: g.id == ^id,
          where: g.site_id == ^site.id,
          preload: [funnels: :steps]
        )
      )
      |> Multi.run(:funnel_ids_to_wipe, fn
        _, %{goal: nil} ->
          {:error, :not_found}

        _, %{goal: %{funnels: []}} ->
          {:ok, []}

        _, %{goal: %{funnels: funnels}} ->
          funnels_to_wipe =
            funnels
            |> Enum.filter(&(Enum.count(&1.steps) == Funnel.min_steps()))
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
            from(f in Funnel,
              where: f.id in ^funnel_ids
            )
          )
      end)
      |> Multi.delete_all(
        :delete_goals,
        fn _ ->
          from g in Goal,
            where: g.id == ^id,
            where: g.site_id == ^site.id
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
end
