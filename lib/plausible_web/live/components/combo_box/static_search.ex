defmodule PlausibleWeb.Live.Components.ComboBox.StaticSearch do
  @moduledoc """
  Default suggestion engine for the `ComboBox` component.

  Assumes, the user have already queried the database and the data set is
  small enough to be kept in state and filtered based on external input.

  Favours exact matches. Skips entries shorter than input.
  Allows fuzzy matching based on Jaro Distance.
  """

  @spec suggest(String.t(), [{any(), any()}]) :: [{any(), any()}]
  def suggest(input, choices, opts \\ []) do
    input = String.trim(input)

    if input != "" do
      weight_threshold = Keyword.get(opts, :weight_threshold, 0.6)

      choices
      |> Enum.map(fn
        {_, value} = choice ->
          {choice, weight(value, input, opts)}

        value ->
          {value, weight(value, input, opts)}
      end)
      |> Enum.reject(fn {_choice, weight} -> weight < weight_threshold end)
      |> Enum.sort_by(fn {_choice, weight} -> weight end, :desc)
      |> Enum.map(fn {choice, _weight} -> choice end)
    else
      choices
    end
  end

  defp weight(value, input, opts) do
    to_str = Keyword.get(opts, :to_string, &to_string/1)
    value = to_str.(value)

    case {value, input} do
      {value, input} when value == input ->
        3

      {value, input} when byte_size(input) > byte_size(value) ->
        0

      {value, input} ->
        input = String.downcase(input)
        value = String.downcase(value)
        weight = if String.contains?(value, input), do: 1, else: 0
        weight + String.jaro_distance(value, input)
    end
  end
end
