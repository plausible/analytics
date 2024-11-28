defmodule Plausible.Stats.SQL.WhereBuilder do
  @moduledoc """
  A module for building am ecto where clause of a query out of a query.
  """

  import Ecto.Query
  import Plausible.Stats.Time, only: [utc_boundaries: 2]
  import Plausible.Stats.Filters.Utils, only: [page_regex: 1]

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
      e.site_id == ^site.id and e.timestamp >= ^first_datetime and e.timestamp <= ^last_datetime
    )
  end

  defp filter_site_time_range(:sessions, site, query) do
    {first_datetime, last_datetime} = utc_boundaries(query, site)

    # Counts each _active_ session in time range even if they started before
    dynamic(
      [s],
      # Currently, the sessions table in ClickHouse only has `start` column
      # in its primary key. This means that filtering by `timestamp` is not
      # considered when estimating number of returned rows from index
      # for sample factor calculation. The redundant lower bound `start` condition
      # ensures the lower bound time filter is still present as primary key
      # condition and the sample factor estimation has minimal skew.
      #
      # Without it, the sample factor would be greatly overestimated for large sites,
      # as query would be estimated to return _all_ rows matching other conditions
      # before `start == last_datetime`.
      s.site_id == ^site.id and
        s.start >= ^NaiveDateTime.add(first_datetime, -7, :day) and
        s.timestamp >= ^first_datetime and
        s.start <= ^last_datetime
    )
  end

  defp add_filter(table, query, [:ignore_in_totals_query, filter]) do
    add_filter(table, query, filter)
  end

  defp add_filter(table, query, [:not, filter]) do
    dynamic([e], not (^add_filter(table, query, filter)))
  end

  defp add_filter(table, query, [:and, filters]) do
    filters
    |> Enum.map(&add_filter(table, query, &1))
    |> Enum.reduce(fn condition, acc -> dynamic([], ^acc and ^condition) end)
  end

  defp add_filter(table, query, [:or, filters]) do
    filters
    |> Enum.map(&add_filter(table, query, &1))
    |> Enum.reduce(fn condition, acc -> dynamic([], ^acc or ^condition) end)
  end

  defp add_filter(:events, _query, [:is, "event:name", clauses, %{case_sensitive: false}]) do
    clauses = Enum.map(clauses, &String.downcase/1)
    dynamic([e], fragment("lower(?)", e.name) in ^clauses)
  end

  defp add_filter(:events, _query, [:is, "event:name", clauses]) do
    dynamic([e], e.name in ^clauses)
  end

  defp add_filter(:events, query, [_, "event:goal" | _rest] = filter) do
    Plausible.Goals.Filters.add_filter(query, filter)
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
         _query,
         [_, "visit:" <> key | _rest] = filter
       ) do
    # Filter events query with visit dimension if possible
    field_name = db_field_name(key)

    if Enum.member?(@sessions_only_visit_fields, field_name) do
      true
    else
      filter_field(field_name, filter)
    end
  end

  defp add_filter(:sessions, _query, [_, "visit:entry_props:" <> prop_name | _rest] = filter) do
    filter_custom_prop(prop_name, :entry_meta, filter)
  end

  defp add_filter(:sessions, _query, [_, "visit:" <> key | _rest] = filter) do
    filter_field(db_field_name(key), filter)
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

  defp filter_custom_prop(prop_name, column_name, [:is, _, clauses, %{case_sensitive: false}]) do
    clauses = clauses |> Enum.map(&String.downcase/1)
    none_value_included = Enum.member?(clauses, "(none)")

    dynamic(
      [t],
      (has_key(t, column_name, ^prop_name) and
         fragment("lower(?)", get_by_key(t, column_name, ^prop_name)) in ^clauses) or
        (^none_value_included and not has_key(t, column_name, ^prop_name))
    )
  end

  defp filter_custom_prop(prop_name, column_name, [:is, _, clauses | _rest]) do
    none_value_included = Enum.member?(clauses, "(none)")

    dynamic(
      [t],
      (has_key(t, column_name, ^prop_name) and get_by_key(t, column_name, ^prop_name) in ^clauses) or
        (^none_value_included and not has_key(t, column_name, ^prop_name))
    )
  end

  defp filter_custom_prop(prop_name, column_name, [:is_not, _, clauses | _rest]) do
    none_value_included = Enum.member?(clauses, "(none)")

    dynamic(
      [t],
      (has_key(t, column_name, ^prop_name) and
         get_by_key(t, column_name, ^prop_name) not in ^clauses) or
        (^none_value_included and
           has_key(t, column_name, ^prop_name) and
           get_by_key(t, column_name, ^prop_name) not in ^clauses) or
        (not (^none_value_included) and not has_key(t, column_name, ^prop_name))
    )
  end

  defp filter_custom_prop(prop_name, column_name, [:matches_wildcard, dimension, clauses | rest]) do
    regexes = Enum.map(clauses, &page_regex/1)

    filter_custom_prop(prop_name, column_name, [:matches, dimension, regexes | rest])
  end

  defp filter_custom_prop(prop_name, column_name, [
         :matches_wildcard_not,
         dimension,
         clauses | rest
       ]) do
    regexes = Enum.map(clauses, &page_regex/1)

    filter_custom_prop(prop_name, column_name, [:matches_not, dimension, regexes | rest])
  end

  defp filter_custom_prop(prop_name, column_name, [:matches, _dimension, clauses | _rest]) do
    dynamic(
      [t],
      has_key(t, column_name, ^prop_name) and
        fragment(
          "arrayExists(k -> match(?, k), ?)",
          get_by_key(t, column_name, ^prop_name),
          ^clauses
        )
    )
  end

  defp filter_custom_prop(prop_name, column_name, [:matches_not, _dimension, clauses | _rest]) do
    dynamic(
      [t],
      has_key(t, column_name, ^prop_name) and
        fragment(
          "not(arrayExists(k -> match(?, k), ?))",
          get_by_key(t, column_name, ^prop_name),
          ^clauses
        )
    )
  end

  defp filter_custom_prop(prop_name, column_name, [
         :contains,
         _dimension,
         clauses,
         %{case_sensitive: false}
       ]) do
    dynamic(
      [t],
      has_key(t, column_name, ^prop_name) and
        fragment(
          "multiSearchAnyCaseInsensitive(?, ?)",
          get_by_key(t, column_name, ^prop_name),
          ^clauses
        )
    )
  end

  defp filter_custom_prop(prop_name, column_name, [:contains, _dimension, clauses | _rest]) do
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

  defp filter_custom_prop(prop_name, column_name, [:contains_not, _dimension, clauses | _rest]) do
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

  defp filter_field(db_field, [:matches_wildcard, _dimension, glob_exprs | _rest]) do
    page_regexes = Enum.map(glob_exprs, &page_regex/1)

    dynamic(
      [x],
      fragment("multiMatchAny(?, ?)", type(field(x, ^db_field), :string), ^page_regexes)
    )
  end

  defp filter_field(db_field, [:matches_wildcard_not | rest]) do
    dynamic([], not (^filter_field(db_field, [:matches_wildcard | rest])))
  end

  defp filter_field(db_field, [:contains, _dimension, values, %{case_sensitive: false}]) do
    dynamic(
      [x],
      fragment("multiSearchAnyCaseInsensitive(?, ?)", type(field(x, ^db_field), :string), ^values)
    )
  end

  defp filter_field(db_field, [:contains, _dimension, values | _rest]) do
    dynamic([x], fragment("multiSearchAny(?, ?)", type(field(x, ^db_field), :string), ^values))
  end

  defp filter_field(db_field, [:contains_not | rest]) do
    dynamic([], not (^filter_field(db_field, [:contains | rest])))
  end

  defp filter_field(db_field, [:matches, _dimension, clauses | _rest]) do
    dynamic(
      [x],
      fragment("multiMatchAny(?, ?)", type(field(x, ^db_field), :string), ^clauses)
    )
  end

  defp filter_field(db_field, [:matches_not | rest]) do
    dynamic([], not (^filter_field(db_field, [:matches | rest])))
  end

  defp filter_field(db_field, [:is, _dimension, clauses, %{case_sensitive: false}]) do
    list = clauses |> Enum.map(&db_field_val(db_field, &1)) |> Enum.map(&String.downcase/1)
    dynamic([x], fragment("lower(?)", field(x, ^db_field)) in ^list)
  end

  defp filter_field(db_field, [:is, _dimension, clauses | _rest]) do
    list = clauses |> Enum.map(&db_field_val(db_field, &1))
    dynamic([x], field(x, ^db_field) in ^list)
  end

  defp filter_field(db_field, [:is_not | rest]) do
    dynamic([], not (^filter_field(db_field, [:is | rest])))
  end

  @no_ref "Direct / None"
  @not_set "(not set)"

  defp db_field_name("channel"), do: :acquisition_channel
  defp db_field_name(name), do: String.to_existing_atom(name)

  defp db_field_val(:source, @no_ref), do: ""
  defp db_field_val(:referrer, @no_ref), do: ""
  defp db_field_val(:utm_medium, @no_ref), do: ""
  defp db_field_val(:utm_source, @no_ref), do: ""
  defp db_field_val(:utm_campaign, @no_ref), do: ""
  defp db_field_val(:utm_content, @no_ref), do: ""
  defp db_field_val(:utm_term, @no_ref), do: ""
  defp db_field_val(_, @not_set), do: ""
  defp db_field_val(_, val), do: val
end
