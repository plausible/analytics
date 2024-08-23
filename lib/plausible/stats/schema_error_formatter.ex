defmodule Plausible.Stats.SchemaErrorFormatter do
  @moduledoc false

  @no_matches "Expected exactly one of the schemata to match, but none of them did."

  def format(errors, params) do
    errors
    |> Enum.map(fn {error, path} ->
      value = JSONPointer.get!(params, path)

      "#{path}: #{reword(path, error, value)}"
    end)
    |> Enum.join("\n")
  end

  defp reword("#/dimensions/" <> _, @no_matches, value), do: "Invalid dimension #{i(value)}"
  defp reword("#/metrics/" <> _, @no_matches, value), do: "Invalid metric #{i(value)}"
  defp reword("#/filters/" <> _, @no_matches, value), do: "Invalid filter #{i(value)}"
  defp reword("#/date_range", @no_matches, value), do: "Invalid date range #{i(value)}"

  defp reword(_path, error, _value), do: error

  defp i(value), do: inspect(value, charlists: :as_lists)
end
