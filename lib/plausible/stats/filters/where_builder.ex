defmodule Plausible.Stats.Filters.WhereBuilder do
  @moduledoc """
  A module for building a where clause of a query out of a query.
  """

  import Ecto.Query
  import Plausible.Stats.Base, only: [page_regex: 1, utc_boundaries: 2]

  alias Plausible.Stats.Query

  use Plausible.Stats.Fragments

  @sessions_only_visit_fields [
    :entry_page,
    :exit_page,
    :entry_page_hostname,
    :exit_page_hostname
  ]

  # Builds WHERE clause for a given Query against sessions or events table
  def build(table, site, query) do
    base_condition = filter_site_time_range(table, site, query)

    query.filters
    |> Enum.map(&add_filter(query, table, &1))
    |> Enum.reduce(base_condition, fn condition, acc -> dynamic([], ^acc and ^condition) end)
  end

  defp filter_site_time_range(:events, site, query) do
    {first_datetime, last_datetime} = utc_boundaries(query, site)

    dynamic(
      [e],
      e.site_id == ^site.id and e.timestamp >= ^first_datetime and e.timestamp < ^last_datetime
    )
  end

  defp filter_site_time_range(:sessions, site, %Query{experimental_session_count?: true} = query) do
    {first_datetime, last_datetime} = utc_boundaries(query, site)

    # Counts each _active_ session in time range even if they started before
    dynamic(
      [s],
      s.site_id == ^site.id and s.timestamp >= ^first_datetime and s.start < ^last_datetime
    )
  end

  defp filter_site_time_range(:sessions, site, query) do
    {first_datetime, last_datetime} = utc_boundaries(query, site)

    dynamic(
      [s],
      s.site_id == ^site.id and s.start >= ^first_datetime and s.start < ^last_datetime
    )
  end

  # :TODO: defp
  def add_filter(_query, :events, [:is, "event:name", name]) do
    dynamic([e], e.name == ^name)
  end

  def add_filter(_query, :events, [:member, "event:name", list]) do
    dynamic([e], e.name in ^list)
  end

  def add_filter(_query, :events, [:is, "event:goal", {:page, path}]) do
    dynamic([e], e.pathname == ^path and e.name == "pageview")
  end

  def add_filter(_query, :events, [:matches, "event:goal", {:page, expr}]) do
    regex = page_regex(expr)

    dynamic([e], fragment("match(?, ?)", e.pathname, ^regex) and e.name == "pageview")
  end

  def add_filter(_query, :events, [:is, "event:goal", {:event, event}]) do
    dynamic([e], e.name == ^event)
  end

  def add_filter(_query, :events, [:member, "event:goal", clauses]) do
    {events, pages} = split_goals(clauses)

    dynamic([e], (e.pathname in ^pages and e.name == "pageview") or e.name in ^events)
  end

  def add_filter(_query, :events, [:matches_member, "event:goal", clauses]) do
    {events, pages} = split_goals(clauses, &page_regex/1)

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
  end

  def add_filter(_query, :events, [_, "event:page" | _rest] = filter) do
    filter_field(:pathname, filter)
  end

  def add_filter(_query, :events, [_, "event:hostname" | _rest] = filter) do
    filter_field(:hostname, filter)
  end

  def add_filter(_query, :events, [_, "event:props:" <> prop_name | _rest] = filter) do
    filter_custom_prop(prop_name, :meta, filter)
  end

  def add_filter(_query, :events, [_, "visit:entry_props:" <> _prop_name | _rest]) do
    true
  end

  def add_filter(
        %Query{experimental_reduced_joins?: true},
        :events,
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

  def add_filter(_query, :events, [_, "visit:" <> _key | _rest]) do
    true
  end

  def add_filter(_query, :sessions, [_, "visit:entry_props:" <> prop_name | _rest] = filter) do
    filter_custom_prop(prop_name, :entry_meta, filter)
  end

  def add_filter(_query, :sessions, [_, "visit:" <> key | _rest] = filter) do
    filter_field(String.to_existing_atom(key), filter)
  end

  def add_filter(_query, :sessions, [_, "event:" <> _ | _rest]) do
    # Cannot apply sessions filters directly on session query where clause.
    true
  end

  defp filter_custom_prop(prop_name, column_name, [:is, _, "(none)"]) do
    dynamic([t], not has_key(t, column_name, ^prop_name))
  end

  defp filter_custom_prop(prop_name, column_name, [:is, _, value]) do
    dynamic(
      [t],
      has_key(t, column_name, ^prop_name) and get_by_key(t, column_name, ^prop_name) == ^value
    )
  end

  defp filter_custom_prop(prop_name, column_name, [:is_not, _, "(none)"]) do
    dynamic([t], has_key(t, column_name, ^prop_name))
  end

  defp filter_custom_prop(prop_name, column_name, [:is_not, _, value]) do
    dynamic(
      [t],
      not has_key(t, column_name, ^prop_name) or get_by_key(t, column_name, ^prop_name) != ^value
    )
  end

  defp filter_custom_prop(prop_name, column_name, [:matches, _, value]) do
    regex = page_regex(value)

    dynamic(
      [t],
      has_key(t, column_name, ^prop_name) and
        fragment("match(?, ?)", get_by_key(t, column_name, ^prop_name), ^regex)
    )
  end

  defp filter_custom_prop(prop_name, column_name, [:member, _, values]) do
    none_value_included = Enum.member?(values, "(none)")

    dynamic(
      [t],
      (has_key(t, column_name, ^prop_name) and get_by_key(t, column_name, ^prop_name) in ^values) or
        (^none_value_included and not has_key(t, column_name, ^prop_name))
    )
  end

  defp filter_custom_prop(prop_name, column_name, [:not_member, _, values]) do
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

  defp filter_custom_prop(prop_name, column_name, [:matches_member, _, clauses]) do
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

  defp filter_field(db_field, [:is, _key, value]) do
    value = db_field_val(db_field, value)
    dynamic([x], field(x, ^db_field) == ^value)
  end

  defp filter_field(db_field, [:is_not, _key, value]) do
    value = db_field_val(db_field, value)
    dynamic([x], field(x, ^db_field) != ^value)
  end

  defp filter_field(db_field, [:matches_member, _key, glob_exprs]) do
    page_regexes = Enum.map(glob_exprs, &page_regex/1)
    dynamic([x], fragment("multiMatchAny(?, ?)", field(x, ^db_field), ^page_regexes))
  end

  defp filter_field(db_field, [:not_matches_member, _key, glob_exprs]) do
    page_regexes = Enum.map(glob_exprs, &page_regex/1)
    dynamic([x], fragment("not(multiMatchAny(?, ?))", field(x, ^db_field), ^page_regexes))
  end

  defp filter_field(db_field, [:matches, _key, glob_expr]) do
    regex = page_regex(glob_expr)
    dynamic([x], fragment("match(?, ?)", field(x, ^db_field), ^regex))
  end

  defp filter_field(db_field, [:does_not_match, _key, glob_expr]) do
    regex = page_regex(glob_expr)
    dynamic([x], fragment("not(match(?, ?))", field(x, ^db_field), ^regex))
  end

  defp filter_field(db_field, [:member, _key, list]) do
    list = Enum.map(list, &db_field_val(db_field, &1))
    dynamic([x], field(x, ^db_field) in ^list)
  end

  defp filter_field(db_field, [:not_member, _key, list]) do
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

  defp split_goals(clauses, map_fn \\ &Function.identity/1) do
    groups =
      Enum.group_by(clauses, fn {goal_type, _v} -> goal_type end, fn {_k, val} -> map_fn.(val) end)

    {
      Map.get(groups, :event, []),
      Map.get(groups, :page, [])
    }
  end
end
