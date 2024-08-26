defmodule Plausible.Stats.JSONSchema do
  @moduledoc """
  Module for validating query parameters against JSON schema.

  Note that `internal` queries expose some metrics, filter types and other features not
  available on the public API.
  """

  @external_resource "priv/json-schemas/query-api-schema.json"

  @raw_public_schema Application.app_dir(:plausible, "priv/json-schemas/query-api-schema.json")
                     |> File.read!()
                     |> Jason.decode!()

  @public_query_schema ExJsonSchema.Schema.resolve(@raw_public_schema)

  @internal_query_schema @raw_public_schema
                         # Add overrides for things allowed in the internal API
                         |> JSONPointer.add!(
                           "#/definitions/filter_entry/oneOf/0/items/0/enum/0",
                           "matches"
                         )
                         |> JSONPointer.add!(
                           "#/definitions/filter_entry/oneOf/0/items/0/enum/0",
                           "does_not_match"
                         )
                         |> JSONPointer.add!("#/definitions/metric/oneOf/0", %{
                           "const" => "time_on_page"
                         })
                         |> JSONPointer.add!("#/definitions/date_range/oneOf/0", %{
                           "const" => "30m"
                         })
                         |> JSONPointer.add!("#/definitions/date_range/oneOf/0", %{
                           "const" => "realtime"
                         })
                         |> ExJsonSchema.Schema.resolve()

  def validate(schema_type, params) do
    case ExJsonSchema.Validator.validate(schema(schema_type), params) do
      :ok -> :ok
      {:error, errors} -> {:error, format_errors(errors, params)}
    end
  end

  def raw_public_schema(), do: @raw_public_schema

  defp schema(:public), do: @public_query_schema
  defp schema(:internal), do: @internal_query_schema

  defp format_errors(errors, params) do
    errors
    |> Enum.map_join("\n", fn {error, path} ->
      value = JSONPointer.get!(params, path)

      "#{path}: #{reword(path, error, value)}"
    end)
  end

  @no_matches "Expected exactly one of the schemata to match, but none of them did."

  defp reword("#/dimensions/" <> _, @no_matches, value), do: "Invalid dimension #{i(value)}"
  defp reword("#/metrics/" <> _, @no_matches, value), do: "Invalid metric #{i(value)}"
  defp reword("#/filters/" <> _, @no_matches, value), do: "Invalid filter #{i(value)}"
  defp reword("#/date_range", @no_matches, value), do: "Invalid date range #{i(value)}"

  defp reword("#/order_by/" <> _, @no_matches, value) do
    "Invalid value in order_by #{i(value)}"
  end

  defp reword(_path, error, _value), do: error

  defp i(value), do: inspect(value, charlists: :as_lists)
end
