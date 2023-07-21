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
    input_len = String.length(input)

    options
    |> Enum.reject(fn {_, value} ->
      input_len > String.length(to_string(value))
    end)
    |> Enum.sort_by(
      fn {_, value} ->
        if to_string(value) == input do
          3
        else
          value = to_string(value)
          input = String.downcase(input)
          value = String.downcase(value)
          weight = if String.contains?(value, input), do: 1, else: 0
          weight + String.jaro_distance(value, input)
        end
      end,
      :desc
    )
  end
end
