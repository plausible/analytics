defmodule PlausibleWeb.Live.Components.ComboBox.StaticSearch do
  @moduledoc """
  Default suggestion engine for the `ComboBox` component.

  Assumes, the user have already queried the database and the data set is
  small enough to be kept in state and filtered based on external input.

  Favours exact matches. Skips entries shorter than input.
  Allows fuzzy matching based on Jaro Distance.
  """

  @spec suggest(String.t(), [{any(), any()}]) :: [{any(), any()}]
  def suggest(input, options) do
    options
    |> Enum.map(fn {_, value} = option -> {option, weight(value, input)} end)
    |> Enum.reject(fn {_option, weight} -> weight < 0.6 end)
    |> Enum.sort_by(fn {_option, weight} -> weight end, :desc)
    |> Enum.map(fn {option, _weight} -> option end)
  end

  defp weight(value, input) do
    value = to_string(value)

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
