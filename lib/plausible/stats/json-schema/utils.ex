defmodule Plausible.Stats.JSONSchema.Utils do
  @moduledoc """
  Module for traversing and modifying JSON schemas.
  """

  @type json :: map() | list() | String.t() | number() | boolean() | nil
  @type transform_fun :: (json() -> json() | :remove)

  @spec traverse(map(), transform_fun()) :: map() | :remove
  def traverse(json, fun) when is_map(json) do
    result =
      Enum.reduce(json, %{}, fn {k, v}, acc ->
        case traverse(v, fun) do
          :remove -> acc
          transformed_v -> Map.put(acc, k, transformed_v)
        end
      end)

    case result do
      map when map_size(map) == 0 -> fun.(%{})
      map -> fun.(map)
    end
  end

  @spec traverse(list(), transform_fun()) :: list() | :remove
  def traverse(json, fun) when is_list(json) do
    result =
      Enum.reduce(json, [], fn v, acc ->
        case traverse(v, fun) do
          :remove -> acc
          transformed_v -> [transformed_v | acc]
        end
      end)
      |> Enum.reverse()

    case result do
      [] -> fun.([])
      list -> fun.(list)
    end
  end

  @spec traverse(String.t() | number() | boolean() | nil, transform_fun()) :: json() | :remove
  def traverse(value, fun), do: fun.(value)
end
