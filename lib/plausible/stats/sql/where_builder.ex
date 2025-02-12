defmodule Plausible.Stats.SQL.WhereBuilder do
  @moduledoc """
  A module for building am ecto where clause of a query out of a query.
  """

  import Ecto.Query
  import Plausible.Stats.Time, only: [utc_boundaries: 1]
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
  def build(table, query) do
    base_condition = filter_site_time_range(table, query)

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

  defp filter_site_time_range(:events, query) do
    {first_datetime, last_datetime} = utc_boundaries(query)

    dynamic(
      [e],
      e.site_id == ^query.site_id and e.timestamp >= ^first_datetime and
        e.timestamp <= ^last_datetime
    )
  end

  defp filter_site_time_range(:sessions, query) do
    {first_datetime, last_datetime} = utc_boundaries(query)

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
      s.site_id == ^query.site_id and
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

  defp add_filter(_table, query, [:has_done, filter]) do
    condition =
      dynamic([], ^filter_site_time_range(:events, query) and ^add_filter(:events, query, filter))

    dynamic(
      [t],
      t.session_id in subquery(from(e in "events_v2", where: ^condition, select: e.session_id))
    )
  end

  defp add_filter(table, query, [:has_not_done, filter]) do
    dynamic([], not (^add_filter(table, query, [:has_done, filter])))
  end

  defp add_filter(:events, _query, [:is, "event:name" | _rest] = filter) do
    in_clause(col_value(:name), filter)
  end

  defp add_filter(:events, query, [_, "event:goal" | _rest] = filter) do
    Plausible.Stats.Goals.add_filter(query, filter)
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

  defp filter_custom_prop(prop_name, column_name, [:is, _, clauses | _rest] = filter) do
    none_value_included = Enum.member?(clauses, "(none)")
    prop_value_expr = custom_prop_value(column_name, prop_name)

    dynamic(
      [t],
      (has_key(t, column_name, ^prop_name) and ^in_clause(prop_value_expr, filter)) or
        (^none_value_included and not has_key(t, column_name, ^prop_name))
    )
  end

  defp filter_custom_prop(prop_name, column_name, [:is_not, _, clauses | _rest] = filter) do
    none_value_included = Enum.member?(clauses, "(none)")
    prop_value_expr = custom_prop_value(column_name, prop_name)

    dynamic(
      [t],
      (has_key(t, column_name, ^prop_name) and
         not (^in_clause(prop_value_expr, filter))) or
        (^none_value_included and
           has_key(t, column_name, ^prop_name) and
           not (^in_clause(prop_value_expr, filter))) or
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

  defp filter_custom_prop(prop_name, column_name, [:contains | _rest] = filter) do
    dynamic(
      [t],
      has_key(t, column_name, ^prop_name) and
        ^contains_clause(custom_prop_value(column_name, prop_name), filter)
    )
  end

  defp filter_custom_prop(prop_name, column_name, [:contains_not | _] = filter) do
    dynamic(
      [t],
      has_key(t, column_name, ^prop_name) and
        not (^contains_clause(custom_prop_value(column_name, prop_name), filter))
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

  defp filter_field(db_field, [:contains | _rest] = filter) do
    contains_clause(col_value_string(db_field), filter)
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

  defp filter_field(db_field, [:is, _dimension, clauses | _rest] = filter) do
    list = clauses |> Enum.map(&db_field_val(db_field, &1))
    in_clause(col_value(db_field), filter, list)
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

  defp col_value(column_name) do
    dynamic([t], field(t, ^column_name))
  end

  # Needed for string functions to work properly
  defp col_value_string(column_name) do
    dynamic([t], type(field(t, ^column_name), :string))
  end

  defp custom_prop_value(column_name, prop_name) do
    dynamic([t], get_by_key(t, column_name, ^prop_name))
  end

  defp in_clause(value_expression, [_, _, clauses | _] = filter, values \\ nil) do
    values = values || clauses

    if case_sensitive?(filter) do
      dynamic([t], ^value_expression in ^values)
    else
      values = values |> Enum.map(&String.downcase/1)
      dynamic([t], fragment("lower(?)", ^value_expression) in ^values)
    end
  end

  defp contains_clause(value_expression, [_, _, clauses | _] = filter) do
    if case_sensitive?(filter) do
      dynamic(
        [x],
        fragment("multiSearchAny(?, ?)", ^value_expression, ^clauses)
      )
    else
      dynamic(
        [x],
        fragment("multiSearchAnyCaseInsensitive(?, ?)", ^value_expression, ^clauses)
      )
    end
  end

  defp case_sensitive?([_, _, _, %{case_sensitive: false}]), do: false
  defp case_sensitive?(_), do: true
end
