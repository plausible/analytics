defmodule Plausible.Stats.SQL.WhereBuilder do
  @moduledoc """
  A module for building am ecto where clause of a query out of a query.
  """

  import Ecto.Query
  import Plausible.Stats.Time, only: [utc_boundaries: 2]
  import Plausible.Stats.Filters.Utils, only: [page_regex: 1]

  alias Plausible.Stats.Query

  use Plausible.Stats.SQL.Fragments

  require Logger

  @sessions_only_visit_fields [
    :entry_page,
    :exit_page,
    :entry_page_hostname,
    :exit_page_hostname
  ]

  @doc "Builds WHERE clause for a given Query against sessions or events table"
  def build(table, site, query) do
    base_condition = filter_site_time_range(table, site, query)

    query.filters
    |> Enum.map(&add_filter(table, query, &1))
    |> Enum.reduce(base_condition, fn condition, acc -> dynamic([], ^acc and ^condition) end)
  end

  @doc """
  Builds WHERE clause condition based off of a filter and a custom column name
  Used for special business logic cases

  Accepts nil as the `filter` parameter, in which case the condition is a no-op (WHERE TRUE).
  """
  def build_condition(db_field, filter) do
    if filter do
      filter_field(db_field, filter)
    else
      true
    end
  end

  defp filter_site_time_range(:events, site, query) do
    {first_datetime, last_datetime} = utc_boundaries(query, site)

    dynamic(
      [e],
      e.site_id == ^site.id and e.timestamp >= ^first_datetime and e.timestamp < ^last_datetime
    )
  end

  defp filter_site_time_range(:sessions, site, query) do
    {first_datetime, last_datetime} = utc_boundaries(query, site)

    # Counts each _active_ session in time range even if they started before
    dynamic(
      [s],
      s.site_id == ^site.id and s.timestamp >= ^first_datetime and s.start < ^last_datetime
    )
  end

  defp add_filter(:events, _query, [:is, "event:name", list]) do
    dynamic([e], e.name in ^list)
  end

  defp add_filter(:events, _query, [operation, "event:goal", clauses])
       when operation in [:is, :matches] do
    {events, pages, wildcard?} = split_goals(clauses)

    if wildcard? do
      event_clause =
        if Enum.any?(events) do
          dynamic([x], fragment("multiMatchAny(?, ?)", x.name, ^events))
        else
          dynamic([x], false)
        end

      page_clause =
        if Enum.any?(pages) do
          dynamic(
            [x],
            fragment("multiMatchAny(?, ?)", x.pathname, ^pages) and x.name == "pageview"
          )
        else
          dynamic([x], false)
        end

      where_clause = dynamic([], ^event_clause or ^page_clause)

      dynamic([e], ^where_clause)
    else
      dynamic([e], (e.pathname in ^pages and e.name == "pageview") or e.name in ^events)
    end
  end

  defp add_filter(:events, _query, [_, "event:page" | _rest] = filter) do
    filter_field(:pathname, filter)
  end

  defp add_filter(:events, _query, [_, "event:hostname" | _rest] = filter) do
    filter_field(:hostname, filter)
  end

  defp add_filter(:events, _query, [_, "event:props:" <> prop_name | _rest] = filter) do
    filter_custom_prop(prop_name, :meta, filter)
  end

  defp add_filter(:events, _query, [_, "visit:entry_props:" <> _prop_name | _rest]) do
    true
  end

  defp add_filter(
         :events,
         %Query{experimental_reduced_joins?: true},
         [_, "visit:" <> key | _rest] = filter
       ) do
    # Filter events query if experimental_reduced_joins? is true
    field_name = String.to_existing_atom(key)

    if Enum.member?(@sessions_only_visit_fields, field_name) do
      true
    else
      filter_field(field_name, filter)
    end
  end

  defp add_filter(:events, _query, [_, "visit:" <> _key | _rest]) do
    true
  end

  defp add_filter(:sessions, _query, [_, "visit:entry_props:" <> prop_name | _rest] = filter) do
    filter_custom_prop(prop_name, :entry_meta, filter)
  end

  defp add_filter(:sessions, _query, [_, "visit:" <> key | _rest] = filter) do
    filter_field(String.to_existing_atom(key), filter)
  end

  defp add_filter(:sessions, _query, [_, "event:" <> _ | _rest]) do
    # Cannot apply sessions filters directly on session query where clause.
    true
  end

  defp add_filter(table, _query, filter) do
    Logger.info("Unable to process garbage filter. No results are returned",
      table: table,
      filter: filter
    )

    false
  end

  defp filter_custom_prop(prop_name, column_name, [:is, _, values]) do
    none_value_included = Enum.member?(values, "(none)")

    dynamic(
      [t],
      (has_key(t, column_name, ^prop_name) and get_by_key(t, column_name, ^prop_name) in ^values) or
        (^none_value_included and not has_key(t, column_name, ^prop_name))
    )
  end

  defp filter_custom_prop(prop_name, column_name, [:is_not, _, values]) do
    none_value_included = Enum.member?(values, "(none)")

    dynamic(
      [t],
      (has_key(t, column_name, ^prop_name) and
         get_by_key(t, column_name, ^prop_name) not in ^values) or
        (^none_value_included and
           has_key(t, column_name, ^prop_name) and
           get_by_key(t, column_name, ^prop_name) not in ^values) or
        (not (^none_value_included) and not has_key(t, column_name, ^prop_name))
    )
  end

  defp filter_custom_prop(prop_name, column_name, [:matches, _, clauses]) do
    regexes = Enum.map(clauses, &page_regex/1)

    dynamic(
      [t],
      has_key(t, column_name, ^prop_name) and
        fragment(
          "arrayExists(k -> match(?, k), ?)",
          get_by_key(t, column_name, ^prop_name),
          ^regexes
        )
    )
  end

  defp filter_custom_prop(prop_name, column_name, [:does_not_match, _, clauses]) do
    regexes = Enum.map(clauses, &page_regex/1)

    dynamic(
      [t],
      has_key(t, column_name, ^prop_name) and
        fragment(
          "not(arrayExists(k -> match(?, k), ?))",
          get_by_key(t, column_name, ^prop_name),
          ^regexes
        )
    )
  end

  defp filter_custom_prop(prop_name, column_name, [:contains, _, clauses]) do
    dynamic(
      [t],
      has_key(t, column_name, ^prop_name) and
        fragment(
          "multiSearchAny(?, ?)",
          get_by_key(t, column_name, ^prop_name),
          ^clauses
        )
    )
  end

  defp filter_custom_prop(prop_name, column_name, [:does_not_contain, _, clauses]) do
    dynamic(
      [t],
      has_key(t, column_name, ^prop_name) and
        fragment(
          "not(multiSearchAny(?, ?))",
          get_by_key(t, column_name, ^prop_name),
          ^clauses
        )
    )
  end

  defp filter_field(db_field, [:matches, _key, glob_exprs]) do
    page_regexes = Enum.map(glob_exprs, &page_regex/1)
    dynamic([x], fragment("multiMatchAny(?, ?)", field(x, ^db_field), ^page_regexes))
  end

  defp filter_field(db_field, [:does_not_match, _key, glob_exprs]) do
    page_regexes = Enum.map(glob_exprs, &page_regex/1)
    dynamic([x], fragment("not(multiMatchAny(?, ?))", field(x, ^db_field), ^page_regexes))
  end

  defp filter_field(db_field, [:contains, _key, values]) do
    dynamic([x], fragment("multiSearchAny(?, ?)", field(x, ^db_field), ^values))
  end

  defp filter_field(db_field, [:does_not_contain, _key, values]) do
    dynamic([x], fragment("not(multiSearchAny(?, ?))", field(x, ^db_field), ^values))
  end

  defp filter_field(db_field, [:is, _key, list]) do
    list = Enum.map(list, &db_field_val(db_field, &1))
    dynamic([x], field(x, ^db_field) in ^list)
  end

  defp filter_field(db_field, [:is_not, _key, list]) do
    list = Enum.map(list, &db_field_val(db_field, &1))
    dynamic([x], field(x, ^db_field) not in ^list)
  end

  @no_ref "Direct / None"
  @not_set "(not set)"

  defp db_field_val(:source, @no_ref), do: ""
  defp db_field_val(:referrer, @no_ref), do: ""
  defp db_field_val(:utm_medium, @no_ref), do: ""
  defp db_field_val(:utm_source, @no_ref), do: ""
  defp db_field_val(:utm_campaign, @no_ref), do: ""
  defp db_field_val(:utm_content, @no_ref), do: ""
  defp db_field_val(:utm_term, @no_ref), do: ""
  defp db_field_val(_, @not_set), do: ""
  defp db_field_val(_, val), do: val

  defp split_goals(clauses) do
    wildcard? = Enum.any?(clauses, fn {_, value} -> String.contains?(value, "*") end)
    map_fn = if(wildcard?, do: &page_regex/1, else: &Function.identity/1)

    clauses
    |> Enum.reduce({[], [], wildcard?}, fn
      {:event, value}, {event, page, wildcard?} -> {event ++ [map_fn.(value)], page, wildcard?}
      {:page, value}, {event, page, wildcard?} -> {event, page ++ [map_fn.(value)], wildcard?}
    end)
  end
end
