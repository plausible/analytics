defmodule Plausible.Helpers.ListTraverse do
  @moduledoc """
  This module contains utility functions for parsing and validating lists of values.
  """

  @doc """
  Parses a list of values using a provided parser function.

  ## Parameters

    - `list`: A list of values to be parsed.
    - `parser_function`: A function that takes a single value and returns either
      `{:ok, result}` or `{:error, reason}`.

  ## Returns

    - `{:ok, parsed_list}` if all values are successfully parsed, where `parsed_list`
      is a list containing the results of applying `parser_function` to each value.
    - `{:error, reason}` if any value fails to parse, where `reason` is the error
      returned by the first failing `parser_function` call.

  ## Examples

      iex> parse_list(["1", "2", "3"], &Integer.parse/1)
      {:ok, [1, 2, 3]}

      iex> parse_list(["1", "not_a_number", "3"], &Integer.parse/1)
      {:error, :invalid}

  """
  @spec parse_list(list(), (any() -> {:ok, any()} | {:error, any()})) ::
          {:ok, list()} | {:error, any()}
  def parse_list(list, parser_function) do
    Enum.reduce_while(list, {:ok, []}, fn value, {:ok, results} ->
      case parser_function.(value) do
        {:ok, result} -> {:cont, {:ok, results ++ [result]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  @doc """
  Validates a list of values using a provided parser function.

  Returns `:ok` if all values are valid, or `{:error, reason}` on first invalid value.
  """
  @spec validate_list(list(), (any() -> :ok | {:error, any()})) :: :ok | {:error, any()}
  def validate_list(list, parser_function) do
    Enum.reduce_while(list, :ok, fn value, :ok ->
      case parser_function.(value) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end
end
