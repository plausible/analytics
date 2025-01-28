defmodule Plausible.AssertMatches do
  @doc """
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
    * `any(:float)`
    * `any(:boolean)`
    * `any(:map)`
    * `any(:list)`
    * all above variants of any with a one argument predicate function accepting
      value and returning a boolean, like: `any(:integer, & &1 > 20)`
    * a special case of `any(:string, ~r/regex pattern/)` checking that value is
      a string and matches a pattern
    * shorthand version of the above, `~r/regex pattern/`
    * any artibrary one argument function returning a boolean, like `&is_float/1`
      or `&(&1 < 40 or &1 > 300)`
    * exact(expression) where expression is compared using equality, so that can
      enforce full equality inside a pattern, like: `exact(%{foo: 2})` which will
      fail if the value is something like `%{foo: 2, other: "something}`
    * any other arbitrary expression which is compared the way as if it was wrapped
      with exact * this allows "interpolating" values from schemas and maps without
      rebinding like `user.id` (instead of having to rebind to `user_id` first)

  Usage example:

      n = %{z: 2}

      assert_matches %{
                      a: ^any(:integer, &(&1 > 2)),
                      b: ^any(:string, ~r/baz/),
                      d: [_ | _],
                      e: ^~r/invalid/,
                      f: ^n.z,
                      g: ^(&is_float/1),
                      h: ^exact(%{foo: :bar})
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

  defmacro assert_matches({:=, meta, [pattern, value]}) do
    {var_pattern, pins} =
      Macro.postwalk(pattern, [], fn
        {:^, _meta, {pinned, _, module}} = normal_pin, acc
        when is_atom(pinned) and is_atom(module) ->
          {normal_pin, acc}

        {:^, _meta, [pinned]}, acc ->
          pinned = Plausible.AssertMatches.Internal.transform_predicate(pinned)
          pinned_var = Macro.unique_var(:match, __MODULE__)
          {pinned_var, [{pinned_var, pinned} | acc]}

        other, acc ->
          {other, acc}
      end)

    clean_pattern =
      Enum.reduce(pins, var_pattern, fn {var, _predicate}, pattern ->
        Macro.postwalk(pattern, fn
          ^var -> {:_, [], __MODULE__}
          other -> other
        end)
      end)

    predicate_pattern =
      quote bind_quoted: [
              var_pattern: Macro.escape(var_pattern),
              escaped_pins: Macro.escape(pins),
              pins: pins
            ] do
        escaped_pins
        |> Enum.zip(pins)
        |> Enum.reduce({false, var_pattern}, fn {{escaped_var, escaped_predicate},
                                                 {var, predicate}},
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

    quote do
      value = unquote(value)
      assert unquote(clean_pattern) = value
      assert unquote(var_pattern) = value
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

  defmodule Internal do
    @moduledoc false

    def transform_predicate({:any, _, [value]}) do
      quote do
        Plausible.AssertMatches.Internal.any(unquote(value))
      end
    end

    def transform_predicate({:exact, _, [value]}) do
      quote do
        Plausible.AssertMatches.Internal.exact(unquote(value))
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

    def strip_prefix({{:., _, [_prefix, f]}, _, args}) when f in [:any, :regex, :exact] do
      {f, [], args}
    end

    def strip_prefix(predicate) do
      predicate
    end

    def any(:atom), do: &is_atom/1
    def any(:string), do: &is_binary/1
    def any(:binary), do: &is_binary/1
    def any(:integer), do: &is_integer/1
    def any(:float), do: &is_float/1
    def any(:boolean), do: &is_boolean/1
    def any(:map), do: &is_map/1
    def any(:list), do: &is_list/1

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

    def exact(expr) do
      fn value ->
        value == expr
      end
    end
  end
end
