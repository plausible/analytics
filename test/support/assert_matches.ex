defmodule Plausible.AssertMatches do
  @doc """
  Custom assertion function that allows for flexible matching of expected results.

  This is useful when testing APIs, where some response fields are not deterministic.

  Examples:

      iex> assert_matches %{ key: 1 }, %{ key: expect_any(:integer) }

      iex> assert_matches %{ string: "abc" }, %{ string: "abc" }

      iex> # assert_matches %{ key: 1 }, %{ key: expect_any(:string) }
      # This would raise ExUnit.AssertionError with a diff.

  """
  def assert_matches(data, expected) do
    {equivalent?, left, right} = check_matches(data, expected)

    if not equivalent? do
      raise ExUnit.AssertionError,
        left: left,
        right: right,
        message: "Values did not match"
    end
  end

  defp check_matches(value, expected) do
    case {value, expected} do
      # Main case: If expected value is a function, we assume it's a predicate passed from expect_any
      {value, predicate_fn} when not is_function(value) and is_function(predicate_fn) ->
        if predicate_fn.(value) do
          # :TRICKY: To make ex_unit not highlight the predicate_fn, pretend it was the value passed from left
          {true, value, value}
        else
          {false, value, predicate_fn}
        end

      {value, expected} when is_list(value) and is_list(expected) ->
        match_lists(value, expected)

      {value, expected} when is_map(value) and is_map(expected) ->
        match_maps(value, expected)

      {a, b} when is_tuple(a) and is_tuple(b) ->
        {equivalent?, left, right} = match_lists(Tuple.to_list(a), Tuple.to_list(b))
        {equivalent?, List.to_tuple(left), List.to_tuple(right)}

      {value, expected} ->
        {value == expected, value, expected}
    end
  end

  defp match_lists([], []), do: {true, [], []}
  defp match_lists([], right), do: {false, [], right}
  defp match_lists(left, []), do: {false, left, []}

  defp match_lists([left | left_rest], [right | right_rest]) do
    {equivalent?, left_acc, right_acc} = match_lists(left_rest, right_rest)
    {eq, l, r} = check_matches(left, right)
    {equivalent? and eq, [l | left_acc], [r | right_acc]}
  end

  defp match_maps(left, expected) do
    keys =
      Map.keys(left)
      |> Enum.concat(Map.keys(expected))

    match_maps(keys, left, expected)
  end

  defp match_maps([], _, _), do: {true, %{}, %{}}

  defp match_maps([key | keys], left, expected) do
    {equivalent?, left_result, right_result} = match_maps(keys, left, expected)

    case {left, expected} do
      {%{^key => left_value}, %{^key => right_value}} ->
        {eq, l, r} = check_matches(left_value, right_value)
        {equivalent? and eq, Map.put(left_result, key, l), Map.put(right_result, key, r)}

      {%{^key => left_value}, _} ->
        {false, Map.put(left_result, key, left_value), right_result}

      {_, %{^key => right_value}} ->
        {false, left_result, Map.put(right_result, key, right_value)}
    end
  end

  @doc """
  Asserts that the value matches the expected type. To be used together with `assert_matches`.
  """
  def expect_any(type \\ :any)

  def expect_any(:atom), do: &is_atom/1
  def expect_any(:string), do: &is_binary/1
  def expect_any(:integer), do: &is_integer/1
  def expect_any(:float), do: &is_float/1
  def expect_any(:boolean), do: &is_boolean/1
  def expect_any(:map), do: &is_map/1
  def expect_any(:list), do: &is_list/1
  def expect_any(:any), do: fn _ -> true end

  def expect_any(type, predicate_fn) do
    fn value ->
      expect_any(type).(value) and predicate_fn.(value)
    end
  end
end
