defmodule Plausible.Stats.JSONSchema do
  @moduledoc """
  Module for validating query parameters against JSON schema.

  Note that `internal` queries expose some metrics, filter types and other features not
  available on the public API.
  """

  @external_resource "priv/json-schemas/query-api-schema.json"

  @raw_internal_schema Application.app_dir(:plausible, "priv/json-schemas/query-api-schema.json")
                       |> File.read!()
                       |> Jason.decode!()

  @raw_public_schema (with {:ok, s1, _} <-
                             JSONPointer.remove(
                               @raw_internal_schema,
                               "#/definitions/filter_operation_without_goals/enum/0"
                             ),
                           {:ok, s2, _} <-
                             JSONPointer.remove(
                               s1,
                               "#/definitions/filter_operation_without_goals/enum/0"
                             ),
                           {:ok, s3, _} <-
                             JSONPointer.remove(s2, "#/definitions/date_range_shorthand/oneOf/0"),
                           {:ok, s4, _} <-
                             JSONPointer.remove(s3, "#/definitions/date_range_shorthand/oneOf/0"),
                           {:ok, s5, _} <- JSONPointer.remove(s4, "#/definitions/metric/oneOf/0"),
                           {:ok, s6, _} <- JSONPointer.remove(s5, "#/properties/date") do
                        s6
                      else
                        {:error, message} -> raise message
                        _ -> raise "Something went wrong deriving the public query schema"
                      end)

  @internal_query_schema ExJsonSchema.Schema.resolve(@raw_internal_schema)
  @public_query_schema ExJsonSchema.Schema.resolve(@raw_public_schema)

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
