defmodule Plausible.Segments do
  @moduledoc """
  Module for accessing Segments.
  """
  alias Plausible.Segments.Segment
  alias Plausible.Repo
  import Ecto.Query

  @roles_with_personal_segments [:billing, :viewer, :editor, :admin, :owner, :super_admin]
  @roles_with_maybe_site_segments [:editor, :admin, :owner, :super_admin]

  @type error_not_enough_permissions() :: {:error, :not_enough_permissions}
  @type error_segment_not_found() :: {:error, :segment_not_found}
  @type error_segment_limit_reached() :: {:error, :segment_limit_reached}
  @type error_invalid_segment() :: {:error, {:invalid_segment, Keyword.t()}}
  @type unknown_error() :: {:error, any()}

  @max_segments 500

  @spec index(pos_integer() | nil, Plausible.Site.t(), atom()) ::
          {:ok, [Segment.t()]} | error_not_enough_permissions()
  def index(user_id, %Plausible.Site{} = site, site_role) do
    fields = [:id, :name, :type, :inserted_at, :updated_at, :owner_id]

    site_segments_available? =
      site_segments_available?(site)

    cond do
      site_role in [:public] and
          site_segments_available? ->
        {:ok, get_public_site_segments(site.id, fields -- [:owner_id])}

      site_role in @roles_with_maybe_site_segments and
          site_segments_available? ->
        {:ok, get_segments(user_id, site.id, fields)}

      site_role in @roles_with_personal_segments ->
        {:ok, get_segments(user_id, site.id, fields, only: :personal)}

      true ->
        {:error, :not_enough_permissions}
    end
  end

  @spec get_many(Plausible.Site.t(), list(pos_integer()), Keyword.t()) ::
          {:ok, [Segment.t()]}
  def get_many(%Plausible.Site{} = _site, segment_ids, _opts)
      when segment_ids == [] do
    {:ok, []}
  end

  def get_many(%Plausible.Site{} = site, segment_ids, opts)
      when is_list(segment_ids) do
    fields = Keyword.get(opts, :fields, [:id])

    query =
      from(segment in Segment,
        select: ^fields,
        where: segment.site_id == ^site.id,
        where: segment.id in ^segment_ids
      )

    {:ok, Repo.all(query)}
  end

  @spec get_one(pos_integer(), Plausible.Site.t(), atom(), pos_integer() | nil) ::
          {:ok, Segment.t()}
          | error_not_enough_permissions()
          | error_segment_not_found()
  def get_one(user_id, site, site_role, segment_id) do
    if site_role in roles_with_personal_segments() do
      case do_get_one(user_id, site.id, segment_id) do
        %Segment{} = segment -> {:ok, segment}
        nil -> {:error, :segment_not_found}
      end
    else
      {:error, :not_enough_permissions}
    end
  end

  @spec insert_one(pos_integer(), Plausible.Site.t(), atom(), map()) ::
          {:ok, Segment.t()}
          | error_not_enough_permissions()
          | error_invalid_segment()
          | error_segment_limit_reached()
          | unknown_error()

  def insert_one(
        user_id,
        %Plausible.Site{} = site,
        site_role,
        %{} = params
      ) do
    with :ok <- can_insert_one?(site, site_role, params),
         %{valid?: true} = changeset <-
           Segment.changeset(
             %Segment{},
             Map.merge(params, %{"site_id" => site.id, "owner_id" => user_id})
           ),
         :ok <-
           Segment.validate_segment_data(site, params["segment_data"], true) do
      {:ok, changeset |> Repo.insert!() |> Repo.preload(:owner)}
    else
      %{valid?: false, errors: errors} ->
        {:error, {:invalid_segment, errors}}

      {:error, {:invalid_filters, message}} ->
        {:error, {:invalid_segment, segment_data: {message, []}}}

      {:error, _type} = error ->
        error
    end
  end

  @spec update_one(pos_integer(), Plausible.Site.t(), atom(), pos_integer(), map()) ::
          {:ok, Segment.t()}
          | error_not_enough_permissions()
          | error_invalid_segment()
          | unknown_error()

  def update_one(
        user_id,
        %Plausible.Site{} = site,
        site_role,
        segment_id,
        %{} = params
      ) do
    with {:ok, segment} <- get_one(user_id, site, site_role, segment_id),
         :ok <- can_update_one?(site, site_role, params, segment.type),
         %{valid?: true} = changeset <-
           Segment.changeset(
             segment,
             Map.merge(params, %{"owner_id" => user_id})
           ),
         :ok <-
           Segment.validate_segment_data_if_exists(
             site,
             params["segment_data"],
             true
           ) do
      Repo.update!(changeset)

      {:ok, Repo.reload!(segment) |> Repo.preload(:owner)}
    else
      %{valid?: false, errors: errors} ->
        {:error, {:invalid_segment, errors}}

      {:error, {:invalid_filters, message}} ->
        {:error, {:invalid_segment, segment_data: {message, []}}}

      {:error, _type} = error ->
        error
    end
  end

  def update_goal_in_segments(
        %Plausible.Site{} = site,
        %Plausible.Goal{} = stale_goal,
        %Plausible.Goal{} = updated_goal
      ) do
    # Looks for a pattern like ["is", "event:goal", [...<goal_name>...]] in the filters structure.
    # Added a bunch of whitespace matchers to make sure it's tolerant of valid JSON formatting
    goal_filter_regex =
      ~s(.*?\\[\s*"is",\s*"event:goal",\s*\\[.*?"#{Regex.escape(stale_goal.display_name)}".*?\\]\s*\\].*?)

    segments_to_update =
      from(
        s in Segment,
        where: s.site_id == ^site.id,
        where: fragment("?['filters']::text ~ ?", s.segment_data, ^goal_filter_regex)
      )

    stale_goal_name = stale_goal.display_name

    for segment <- Repo.all(segments_to_update) do
      updated_filters =
        Plausible.Stats.Filters.transform_filters(segment.segment_data["filters"], fn
          ["is", "event:goal", clauses] ->
            new_clauses =
              Enum.map(clauses, fn
                ^stale_goal_name -> updated_goal.display_name
                clause -> clause
              end)

            [["is", "event:goal", new_clauses]]

          _ ->
            nil
        end)

      updated_segment_data = Map.put(segment.segment_data, "filters", updated_filters)

      from(
        s in Segment,
        where: s.id == ^segment.id,
        update: [set: [segment_data: ^updated_segment_data]]
      )
      |> Repo.update_all([])
    end

    :ok
  end

  def after_user_removed_from_site(site, user) do
    Repo.delete_all(
      from segment in Segment,
        where: segment.site_id == ^site.id,
        where: segment.owner_id == ^user.id,
        where: segment.type == :personal
    )

    Repo.update_all(
      from(segment in Segment,
        where: segment.site_id == ^site.id,
        where: segment.owner_id == ^user.id,
        where: segment.type == :site,
        update: [set: [owner_id: nil]]
      ),
      []
    )
  end

  def after_user_removed_from_team(team, user) do
    team_sites_q =
      from(
        site in Plausible.Site,
        where: site.team_id == ^team.id,
        where: parent_as(:segment).site_id == site.id
      )

    Repo.delete_all(
      from segment in Segment,
        as: :segment,
        where: segment.owner_id == ^user.id,
        where: segment.type == :personal,
        where: exists(team_sites_q)
    )

    Repo.update_all(
      from(segment in Segment,
        as: :segment,
        where: segment.owner_id == ^user.id,
        where: segment.type == :site,
        where: exists(team_sites_q),
        update: [set: [owner_id: nil]]
      ),
      []
    )
  end

  def user_removed(user) do
    Repo.delete_all(
      from segment in Segment,
        as: :segment,
        where: segment.owner_id == ^user.id,
        where: segment.type == :personal
    )

    #  Site segments are set to owner=null via ON DELETE SET NULL
  end

  def delete_one(user_id, %Plausible.Site{} = site, site_role, segment_id) do
    with {:ok, segment} <- get_one(user_id, site, site_role, segment_id) do
      cond do
        segment.type == :site and site_role in roles_with_maybe_site_segments() ->
          {:ok, do_delete_one(segment)}

        segment.type == :personal and site_role in roles_with_personal_segments() ->
          {:ok, do_delete_one(segment)}

        true ->
          {:error, :not_enough_permissions}
      end
    end
  end

  @spec do_get_one(pos_integer(), pos_integer(), pos_integer() | nil) ::
          Segment.t() | nil
  defp do_get_one(user_id, site_id, segment_id)

  defp do_get_one(_user_id, _site_id, nil) do
    nil
  end

  defp do_get_one(user_id, site_id, segment_id) do
    query =
      from(segment in Segment,
        where: segment.site_id == ^site_id,
        where: segment.id == ^segment_id,
        where: segment.type == :site or segment.owner_id == ^user_id,
        preload: [:owner]
      )

    Repo.one(query)
  end

  defp do_delete_one(segment) do
    Repo.delete!(segment)
    segment
  end

  defp can_update_one?(%Plausible.Site{} = site, site_role, params, existing_segment_type) do
    updating_to_site_segment? = params["type"] == "site"

    cond do
      (existing_segment_type == :site or
         updating_to_site_segment?) and site_role in roles_with_maybe_site_segments() and
          site_segments_available?(site) ->
        :ok

      existing_segment_type == :personal and not updating_to_site_segment? and
          site_role in roles_with_personal_segments() ->
        :ok

      true ->
        {:error, :not_enough_permissions}
    end
  end

  defp can_insert_one?(%Plausible.Site{} = site, site_role, params) do
    cond do
      count_segments(site.id) >= @max_segments ->
        {:error, :segment_limit_reached}

      params["type"] == "site" and site_role in roles_with_maybe_site_segments() and
          site_segments_available?(site) ->
        :ok

      params["type"] == "personal" and
          site_role in roles_with_personal_segments() ->
        :ok

      true ->
        {:error, :not_enough_permissions}
    end
  end

  defp count_segments(site_id) do
    from(segment in Segment,
      where: segment.site_id == ^site_id
    )
    |> Repo.aggregate(:count, :id)
  end

  def roles_with_personal_segments(), do: [:viewer, :editor, :admin, :owner, :super_admin]
  def roles_with_maybe_site_segments(), do: [:editor, :admin, :owner, :super_admin]

  def site_segments_available?(%Plausible.Site{} = site),
    do: Plausible.Billing.Feature.SiteSegments.check_availability(site.team) == :ok

  @spec get_public_site_segments(pos_integer(), list(atom())) :: [Segment.t()]
  defp get_public_site_segments(site_id, fields) do
    Repo.all(
      from(segment in Segment,
        select: ^fields,
        where: segment.site_id == ^site_id,
        where: segment.type == :site,
        order_by: [desc: segment.updated_at, desc: segment.id]
      )
    )
  end

  @spec get_segments(pos_integer(), pos_integer(), list(atom()), Keyword.t()) :: [Segment.t()]
  defp get_segments(user_id, site_id, fields, opts \\ []) do
    query =
      from(segment in Segment,
        select: ^fields,
        where: segment.site_id == ^site_id,
        order_by: [desc: segment.updated_at, desc: segment.id],
        preload: [:owner]
      )

    query =
      if Keyword.get(opts, :only) == :personal do
        where(query, [segment], segment.type == :personal and segment.owner_id == ^user_id)
      else
        where(
          query,
          [segment],
          segment.type == :site or (segment.type == :personal and segment.owner_id == ^user_id)
        )
      end

    Repo.all(query)
  end

  @doc """
  iex> serialize_first_error([{"name", {"should be at most %{count} byte(s)", [count: 255]}}])
  "name should be at most 255 byte(s)"
  """
  def serialize_first_error(errors) do
    {field, {message, opts}} = List.first(errors)

    formatted_message =
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)

    "#{field} #{formatted_message}"
  end

  @doc """
  This function enriches the segment with site, without actually querying the database for the site again.
  Needed for Plausible.Segments.Segment custom JSON serialization.
  """
  @spec enrich_with_site(Segment.t(), Plausible.Site.t()) :: Segment.t()
  def enrich_with_site(%Segment{} = segment, %Plausible.Site{} = site) do
    Map.put(segment, :site, site)
  end

  @spec get_site_segments_usage_query(list(pos_integer())) :: Ecto.Query.t()
  def get_site_segments_usage_query(site_ids) do
    from(segment in Segment,
      as: :segment,
      where: segment.type == :site,
      where: segment.site_id in ^site_ids
    )
  end
end
