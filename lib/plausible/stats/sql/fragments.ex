defmodule Plausible.Stats.SQL.Fragments do
  @moduledoc """
  Various macros and common SQL fragments used in Stats code.
  """

  defmacro __using__(_) do
    quote do
      import Plausible.Stats.SQL.Fragments
      require Plausible.Stats.SQL.Fragments
    end
  end

  defmacro scale_sample(fragment_) do
    quote do
      fragment("toUInt64(round(? * any(_sample_factor)))", unquote(fragment_))
    end
  end

  defmacro uniq(user_id) do
    quote do
      scale_sample(fragment("uniq(?)", unquote(user_id)))
    end
  end

  defmacro total() do
    quote do
      scale_sample(fragment("count()"))
    end
  end

  defmacro sample_percent() do
    quote do
      fragment("if(any(_sample_factor) > 1, round(100 / any(_sample_factor)), 100)")
    end
  end

  defmacro bounce_rate() do
    quote do
      fragment(
        # :TRICKY: Before PR #4493, we could have sessions where `sum(is_bounce * sign)`
        # is negative, leading to an underflow and >100% bounce rate. This works around
        # that issue.
        "toUInt32(greatest(ifNotFinite(round(sum(is_bounce * sign) / sum(sign) * 100), 0), 0))"
      )
    end
  end

  defmacro visit_duration() do
    quote do
      fragment("toUInt32(ifNotFinite(round(avg(duration * sign)), 0))")
    end
  end

  defmacro coalesce_string(fieldA, fieldB) do
    quote do
      fragment("if(empty(?), ?, ?)", unquote(fieldA), unquote(fieldB), unquote(fieldA))
    end
  end

  @doc """
  Converts time or date and time to the specified timezone.

  Reference: https://clickhouse.com/docs/en/sql-reference/functions/date-time-functions/#totimezone
  """
  defmacro to_timezone(date, timezone) do
    quote do
      fragment("toTimeZone(?, ?)", unquote(date), unquote(timezone))
    end
  end

  @doc """
  Returns the weekstart for `date`. If the weekstart is before the `not_before`
  boundary, `not_before` is returned.

  ## Examples

  In this pseudo-code example, the fragment returns the weekstart. The
  `not_before` boundary is set to the past Saturday, which is before the
  weekstart, therefore the cap does not apply.

    ```
    > this_wednesday = ~D[2022-11-09]
    > past_saturday = ~D[2022-11-05]
    > weekstart_not_before(this_wednesday, past_saturday)
    ~D[2022-11-07]
    ```

  In this other example, the fragment returns Tuesday and not the weekstart.
  The `not_before` boundary is set to Tuesday, which is past the weekstart,
  therefore the cap applies.

    ```
    > this_wednesday = ~D[2022-11-09]
    > this_tuesday = ~D[2022-11-08]
    > weekstart_not_before(this_wednesday, this_tuesday)
    ~D[2022-11-08]
    ```
  """
  defmacro weekstart_not_before(date, not_before) do
    quote do
      fragment(
        "if(toMonday(?) < toDate(?), toDate(?), toMonday(?))",
        unquote(date),
        unquote(not_before),
        unquote(not_before),
        unquote(date)
      )
    end
  end

  @doc """
  Returns whether a key (usually property) exists under `meta.key` array or similar.

  This macro is used for operating on custom properties.

  ## Examples

  `has_key(e, :meta, "some_property_name")` expands to SQL `has(meta.key, "some_property_name")`
  """
  defmacro has_key(table, meta_column, key) do
    quote do
      fragment(
        "has(?, ?)",
        field(unquote(table), ^meta_key_column(unquote(meta_column))),
        unquote(key)
      )
    end
  end

  @doc """
  Returns value of a key (usually property) under `meta.value` array or similar.

  This macro is used for operating on custom properties.
  Callsites should also check whether key exists first in SQL via `has_key` macro.

  ## Examples

  `get_by_key(e, :meta, "some_property_name")` expands to SQL `meta.value[indexOf(meta.key, "some_property")]`
  """
  defmacro get_by_key(table, meta_column, key) do
    quote do
      fragment(
        "?[indexOf(?, ?)]",
        field(unquote(table), ^meta_value_column(unquote(meta_column))),
        field(unquote(table), ^meta_key_column(unquote(meta_column))),
        unquote(key)
      )
    end
  end

  def meta_key_column(:meta), do: :"meta.key"
  def meta_key_column(:entry_meta), do: :"entry_meta.key"

  def meta_value_column(:meta), do: :"meta.value"
  def meta_value_column(:entry_meta), do: :"entry_meta.value"

  @doc """
  Convenience Ecto macro for wrapping a map passed to select_merge_as such that each
  expression gets wrapped in dynamic and set as selected_as.

  ### Examples

    iex> wrap_alias([t], %{ foo: t.column }) |> expand_macro_once
    "%{foo: dynamic([t], selected_as(t.column, :foo))}"
  """
  defmacro wrap_alias(binding, map_literal) do
    update_literal_map_values(map_literal, fn {key, expr} ->
      key_expr =
        if Macro.quoted_literal?(key) do
          key
        else
          quote(do: ^unquote(key))
        end

      quote(do: dynamic(unquote(binding), selected_as(unquote(expr), unquote(key_expr))))
    end)
  end

  @doc """
  Convenience Ecto macro for wrapping select_merge where each value gets in turn passed to selected_as.

  ### Examples

    iex> select_merge_as(q, [t], %{ foo: t.column }) |> expand_macro_once
    "select_merge(q, [], ^wrap_alias([t], %{foo: t.column}))"
  """
  defmacro select_merge_as(q, binding, map_literal) do
    quote do
      select_merge(unquote(q), [], ^wrap_alias(unquote(binding), unquote(map_literal)))
    end
  end

  @doc """
  Macro that helps join two Ecto queries by selecting fields from either one
  """
  defmacro select_join_fields(q, query, list, table_name) do
    quote do
      Enum.reduce(unquote(list), unquote(q), fn metric_or_dimension, q ->
        key = shortname(unquote(query), metric_or_dimension)

        select_merge_as(q, [e, s], %{
          key => field(unquote(table_name), ^key)
        })
      end)
    end
  end

  defp update_literal_map_values({:%{}, ctx, keyword_list}, mapper_fn) do
    {
      :%{},
      ctx,
      Enum.map(keyword_list, fn {key, expr} ->
        {key, mapper_fn.({key, expr})}
      end)
    }
  end

  defp update_literal_map_values(ast, _), do: ast
end
