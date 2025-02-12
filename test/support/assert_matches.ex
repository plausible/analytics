defmodule Plausible.AssertMatches do
  @moduledoc """
  Pattern match assertions wrapper macro extending it with checks expressed
  directly within the pattern.

  The idea here is that the pin (^) operator does not only rebind existing
  binding in the scope but also allows embedding basically any other expression
  to match against the given part of the pattern. Normal pattern matching is
  also supported and both can be mixed. The only caveat so far is that when
  normal patterns fail, only they are listed in the error even if there are
  potentially failing expressions. However, once the normal pattern is fixed,
  they surface.

  Currently, the following expressions can be pinned:

    * `any(:atom)`
    * `any(:string)`
    * `any(:binary)`
    * `any(:integer)`
    * `any(:pos_integer)`
    * `any(:number)`
    * `any(:float)`
    * `any(:boolean)`
    * `any(:map)`
    * `any(:list)`
    * `any(:tuple)`
    * `any(:iso8601_date)`
    * `any(:iso8601_datetime)`
    * `any(:iso8601_naive_datetime)`
    * all above variants of any with a one argument predicate function accepting
      value and returning a boolean, like: `any(:integer, & &1 > 20)`
    * a special case of `any(:string, ~r/regex pattern/)` checking that value is
      a string and matches a pattern
    * shorthand version of the above, `~r/regex pattern/`
    * any artibrary one argument function returning a boolean, like `&is_float/1`
      or `&(&1 < 40 or &1 > 300)`
    * exactly(expression) where expression is compared using equality, so that can
      enforce full equality inside a pattern, like: `exactly(%{foo: 2})` which will
      fail if the value is something like `%{foo: 2, other: "something}`
    * any other arbitrary expression which is compared the way as if it was wrapped
      with `exactly()`; this allows "interpolating" values from schemas and maps without
      rebinding like `user.id` (instead of having to rebind to `user_id` first)

  There's also a special pin type, `strict_map(...)` which can wrap around any map
  in the pattern. It's enforcing that the pattern has enumerated all the keys
  present in the respective map in the pattern matched value. All the above mentioned
  pin expressions can be also used inside `strict_map(...)` and `strict_map()` pins
  can be nested.

  Usage example:

      n = %{z: 2}

      assert_matches %{
                      a: ^any(:integer, &(&1 > 2)),
                      b: ^any(:string, ~r/baz/),
                      d: [_ | _],
                      e: ^~r/invalid/,
                      f: ^n.z,
                      g: ^(&is_float/1),
                      h: ^exactly(%{foo: :bar})
                    } = %{
                      a: 1,
                      b: "twofer",
                      c: :other,
                      d: [1, 2, 3],
                      e: "another string",
                      f: 1,
                      g: 4.2,
                      h: %{foo: :bar, other: "stuff"}
                    }
  """

  @doc @moduledoc
  defmacro assert_matches({:=, meta, [pattern, value]}) do
    {base_strict_pattern, strict_vars} = build_base_strict_pattern(pattern)

    base_strict_pattern = clear_bindings_except(base_strict_pattern, :match_var)

    strict_patterns =
      Enum.map(strict_vars, fn strict_var ->
        build_strict_pattern(base_strict_pattern, strict_var)
      end)

    strict_pattern_matches =
      Enum.map(strict_patterns, fn {strict_pattern, _} ->
        quote do
          assert unquote(strict_pattern) = unquote(value)
        end
      end)

    strict_pattern_checks =
      Enum.map(strict_patterns, fn {strict_pattern, [{strict_var, map_pattern_keys}]} ->
        build_strict_pattern_check(strict_pattern, strict_var, map_pattern_keys, pattern, value)
      end)

    {var_pattern, pins} = build_var_pattern(pattern)

    clean_pattern =
      Enum.reduce(pins, var_pattern, fn {var, _predicate}, pattern ->
        Macro.postwalk(pattern, fn
          ^var -> {:_, [], __MODULE__}
          other -> other
        end)
      end)

    var_pattern = clear_bindings_except(var_pattern, :assert_match)

    predicate_pattern = build_predicate_pattern(var_pattern, pins)

    quote do
      value = unquote(value)
      assert unquote(clean_pattern) = value
      unquote(strict_pattern_matches)
      unquote(strict_pattern_checks)

      assert unquote(var_pattern) = value

      if unquote(length(pins) > 0) do
        {errors?, predicate_pattern} = unquote(predicate_pattern)

        if errors? do
          raise ExUnit.AssertionError,
            message: "match (=) failed",
            left: predicate_pattern,
            right: value,
            expr:
              {:assert_matches, unquote(meta),
               [{:=, [], [unquote(Macro.escape(pattern)), Macro.escape(value)]}]},
            context: {:match, []}
        end
      end
    end
  end

  defp build_base_strict_pattern(pattern) do
    Macro.postwalk(pattern, [], fn
      {:^, _, [{:strict_map, _, _}]} = pin, acc ->
        pinned_var = Macro.unique_var(:match, __MODULE__)

        pin = Macro.update_meta(pin, &Keyword.put(&1, :match_var, pinned_var))

        {pin, [pinned_var | acc]}

      {:^, _, _}, acc ->
        {{:_, [], __MODULE__}, acc}

      other, acc ->
        {other, acc}
    end)
  end

  defp build_strict_pattern(base_strict_pattern, strict_var) do
    Macro.postwalk(base_strict_pattern, [], fn
      {:^, meta, [{:strict_map, _, [pinned]}]}, acc ->
        if meta[:match_var] == strict_var do
          {:%{}, _, map_pattern_values} = pinned
          map_pattern_keys = map_pattern_values |> Enum.map(&elem(&1, 0)) |> Enum.sort()
          {strict_var, [{strict_var, map_pattern_keys} | acc]}
        else
          {
            Macro.postwalk(pinned, fn
              {:^, _, _} ->
                {:_, [], __MODULE__}

              other ->
                other
            end),
            acc
          }
        end

      other, acc ->
        {other, acc}
    end)
  end

  defp build_strict_pattern_check(strict_pattern, strict_var, map_pattern_keys, pattern, value) do
    quote bind_quoted: [
            pattern: Macro.escape(pattern),
            value: value,
            strict_pattern: Macro.escape(strict_pattern),
            var: strict_var,
            escaped_var: Macro.escape(strict_var),
            pattern_keys: map_pattern_keys
          ] do
      var_keys = var |> Map.keys() |> Enum.sort()

      if pattern_keys != var_keys do
        missing_keys = var_keys -- pattern_keys

        map_pattern_values =
          pattern_keys
          |> Enum.map(&{&1, {:_, [], __MODULE__}})
          |> Enum.concat(Enum.map(missing_keys, &{&1, :_MISSING_KEY__}))

        error_pattern =
          Macro.postwalk(strict_pattern, fn
            ^escaped_var -> {:%{}, [], map_pattern_values}
            other -> other
          end)

        raise ExUnit.AssertionError,
          message: "match (=) failed",
          left: error_pattern,
          right: value,
          expr: {:assert_matches, [], [{:=, [], [pattern, Macro.escape(value)]}]},
          context: {:match, []}
      end
    end
  end

  defp build_predicate_pattern(var_pattern, pins) do
    quote bind_quoted: [
            var_pattern: Macro.escape(var_pattern),
            escaped_pins: Macro.escape(pins),
            pins: pins
          ] do
      escaped_pins
      |> Enum.zip(pins)
      |> Enum.reduce({false, var_pattern}, fn {{escaped_var, escaped_predicate}, {var, predicate}},
                                              {errors?, pattern} ->
        result =
          if is_function(predicate, 1) do
            not predicate.(var)
          else
            predicate != var
          end

        if result do
          escaped_predicate = Plausible.AssertMatches.Internal.strip_prefix(escaped_predicate)

          {true,
           Macro.postwalk(pattern, fn
             ^escaped_var -> escaped_predicate
             other -> other
           end)}
        else
          {errors?,
           Macro.postwalk(pattern, fn
             ^escaped_var -> {:_, [], __MODULE__}
             other -> other
           end)}
        end
      end)
    end
  end

  defp build_var_pattern(pattern) do
    Macro.postwalk(pattern, [], fn
      {:^, _meta, [{pinned, _, module}]} = normal_pin, acc
      when is_atom(pinned) and is_atom(module) ->
        {normal_pin, acc}

      {:^, _meta, [{:strict_map, _, [pinned]}]}, acc ->
        {pinned, acc}

      {:^, _meta, [pinned]}, acc ->
        pinned = Plausible.AssertMatches.Internal.transform_predicate(pinned)

        pinned_var =
          Macro.unique_var(:match, __MODULE__)
          |> Macro.update_meta(&Keyword.put(&1, :assert_match, true))

        {pinned_var, [{pinned_var, pinned} | acc]}

      other, acc ->
        {other, acc}
    end)
  end

  defp clear_bindings_except(pattern, except_meta) do
    pattern
    |> Macro.postwalk(fn
      {:^, _, [{name, meta, module}]} = pin when is_atom(name) and is_atom(module) ->
        if meta[except_meta] do
          pin
        else
          {:_, [], __MODULE__}
        end

      other ->
        other
    end)
    |> Macro.postwalk(fn
      {name, meta, module} = var when is_atom(name) and is_atom(module) ->
        if meta[except_meta] do
          var
        else
          {:_, [], __MODULE__}
        end

      other ->
        other
    end)
  end

  defmodule Internal do
    @moduledoc false

    def transform_predicate({:any, _, [value]}) do
      quote do
        Plausible.AssertMatches.Internal.any(unquote(value))
      end
    end

    def transform_predicate({:exactly, _, [value]}) do
      quote do
        Plausible.AssertMatches.Internal.exactly(unquote(value))
      end
    end

    def transform_predicate({:any, _, [value, extra_predicate]}) do
      quote do
        Plausible.AssertMatches.Internal.any(
          unquote(value),
          unquote(extra_predicate)
        )
      end
    end

    def transform_predicate({:sigil_r, _, _} = regex) do
      quote do
        Plausible.AssertMatches.Internal.regex(unquote(regex))
      end
    end

    def transform_predicate(other), do: other

    def strip_prefix({{:., _, [_prefix, f]}, _, args}) when f in [:any, :regex, :exactly] do
      {f, [], args}
    end

    def strip_prefix(predicate) do
      predicate
    end

    def any(:atom), do: &is_atom/1
    def any(:string), do: &is_binary/1
    def any(:binary), do: &is_binary/1
    def any(:integer), do: &is_integer/1
    def any(:number), do: &is_number/1
    def any(:float), do: &is_float/1
    def any(:boolean), do: &is_boolean/1
    def any(:map), do: &is_map/1
    def any(:list), do: &is_list/1
    def any(:tuple), do: &is_tuple/1

    def any(:pos_integer) do
      fn value ->
        is_integer(value) and value > 0
      end
    end

    def any(:iso8601_date) do
      fn value ->
        case Date.from_iso8601(value) do
          {:ok, _} -> true
          _ -> false
        end
      end
    end

    def any(:iso8601_datetime) do
      fn value ->
        case DateTime.from_iso8601(value) do
          {:ok, _, _} -> true
          _ -> false
        end
      end
    end

    def any(:iso8601_naive_datetime) do
      fn value ->
        case NaiveDateTime.from_iso8601(value) do
          {:ok, _} -> true
          _ -> false
        end
      end
    end

    def any(:string, %Regex{} = regex) do
      fn value ->
        any(:string).(value) and regex(regex).(value)
      end
    end

    def any(type, predicate_fn) when is_function(predicate_fn, 1) do
      fn value ->
        any(type).(value) and predicate_fn.(value)
      end
    end

    def regex(regex) do
      fn value ->
        String.match?(value, regex)
      end
    end

    def exactly(expr) do
      fn value ->
        value == expr
      end
    end
  end
end
