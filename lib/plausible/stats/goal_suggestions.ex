defmodule Plausible.Stats.GoalSuggestions do
  @moduledoc false

  use Plausible.Stats.SQL.Fragments

  alias Plausible.{Repo, ClickhouseRepo}
  alias Plausible.Stats.{Query, QueryBuilder}
  import Plausible.Stats.Base
  import Ecto.Query

  # As excluded goal names are interpolated as separate
  # parameters in the query, there's a risk of running
  # against max parameters limit. Given the failure mode
  # in this case is suggesting an event that is already
  # added as a goal, which will be validated when creating,
  # it's safe to trim exclusions list.
  @max_excluded 1000

  defmacrop visitors(e) do
    quote do
      selected_as(
        fragment("toUInt64(round(uniq(?)*any(_sample_factor)))", unquote(e).user_id),
        :visitors
      )
    end
  end

  def suggest_event_names(site, search_input, opts \\ []) do
    matches = "%#{search_input}%"

    site = Repo.preload(site, goals: Plausible.Goals.for_site_query())

    excluded =
      opts
      |> Keyword.get(:exclude, [])
      |> Enum.take(@max_excluded)

    limit = Keyword.get(opts, :limit, 25)

    to_date = Date.utc_today()
    from_date = Date.shift(to_date, month: -6)

    query =
      QueryBuilder.build!(site,
        input_date_range: {:date_range, from_date, to_date},
        metrics: [:pageviews],
        include: [imports: true]
      )

    native_q =
      from(e in base_event_query(query),
        where: fragment("? ilike ?", e.name, ^matches),
        where: e.name not in ["pageview", "engagement"],
        where: fragment("trim(?)", e.name) != "",
        where: e.name == fragment("trim(?)", e.name),
        where: e.name not in ^excluded,
        select: %{
          name: e.name,
          visitors: visitors(e)
        },
        order_by: selected_as(:visitors),
        group_by: e.name
      )
      |> maybe_set_limit(limit)

    date_range = Query.date_range(query)

    imported_q =
      from(i in "imported_custom_events",
        where: i.site_id == ^site.id,
        where: i.import_id in ^Plausible.Imported.complete_import_ids(site),
        where: i.date >= ^date_range.first and i.date <= ^date_range.last,
        where: i.visitors > 0,
        where: fragment("? ilike ?", i.name, ^matches),
        where: fragment("trim(?)", i.name) != "",
        where: i.name == fragment("trim(?)", i.name),
        where: i.name not in ^excluded,
        select: %{
          name: i.name,
          visitors: selected_as(sum(i.visitors), :visitors)
        },
        order_by: selected_as(:visitors),
        group_by: i.name
      )
      |> maybe_set_limit(limit)

    from(e in Ecto.Query.subquery(native_q),
      full_join: i in subquery(imported_q),
      on: e.name == i.name,
      select: selected_as(fragment("if(empty(?), ?, ?)", e.name, i.name, e.name), :name),
      order_by: [desc: e.visitors + i.visitors]
    )
    |> maybe_set_limit(limit)
    |> ClickhouseRepo.all()
    |> Enum.reject(&(String.length(&1) > Plausible.Goal.max_event_name_length()))
  end

  def suggest_custom_property_names(site, search_input, _opts \\ []) do
    filter_query = if search_input == nil, do: "%", else: "%#{search_input}%"

    query = custom_props_query_30d(site)

    search_q =
      from(e in base_event_query(query),
        join: meta in "meta",
        hints: "ARRAY",
        on: true,
        as: :meta,
        select: meta.key,
        where: fragment("? ilike ?", meta.key, ^filter_query),
        group_by: meta.key,
        order_by: [desc: fragment("count(*)")],
        limit: 25
      )

    event_prop_names = ClickhouseRepo.all(search_q)

    allowed_props = site.allowed_event_props || []

    allowed_prop_names =
      if search_input == nil or search_input == "" do
        allowed_props
      else
        search_lower = String.downcase(search_input)

        Enum.filter(allowed_props, fn prop ->
          String.contains?(String.downcase(prop), search_lower)
        end)
      end

    # Combine results, prioritizing event_prop_names (they have usage data),
    # then append allowed_prop_names that aren't already in event_prop_names
    event_prop_set = MapSet.new(event_prop_names)

    allowed_only =
      allowed_prop_names
      |> Enum.reject(&MapSet.member?(event_prop_set, &1))

    event_prop_names ++ Enum.sort(allowed_only)
  end

  def suggest_custom_property_values(site, prop_key, search_input) do
    filter_query = if search_input == nil, do: "%", else: "%#{search_input}%"

    query = custom_props_query_30d(site)

    search_q =
      from(e in base_event_query(query),
        select: get_by_key(e, :meta, ^prop_key),
        where:
          has_key(e, :meta, ^prop_key) and
            fragment(
              "? ilike ?",
              get_by_key(e, :meta, ^prop_key),
              ^filter_query
            ),
        group_by: get_by_key(e, :meta, ^prop_key),
        order_by: [desc: fragment("count(*)")],
        limit: 25
      )

    ClickhouseRepo.all(search_q)
  end

  defp custom_props_query_30d(site) do
    Plausible.Stats.Query.parse_and_build!(
      site,
      %{
        "site_id" => site.domain,
        "date_range" => [
          Date.to_iso8601(Date.shift(Date.utc_today(), day: -30)),
          Date.to_iso8601(Date.utc_today())
        ],
        "metrics" => ["pageviews"],
        "include" => %{"imports" => true}
      }
    )
  end

  defp maybe_set_limit(q, :unlimited) do
    q
  end

  defp maybe_set_limit(q, limit) when is_integer(limit) and limit > 0 do
    limit(q, ^limit)
  end
end
