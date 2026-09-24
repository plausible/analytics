defmodule Plausible.ChangesetHelpers do
  @moduledoc "Helper function for working with Ecto changesets"

  def traverse_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts
        |> Keyword.get(String.to_existing_atom(key), key)
        |> to_string()
      end)
    end)
  end

  @doc """
  iex> serialize_first_error([{"name", {"should be at most %{count} byte(s)", [count: 255]}}])
  "name should be at most 255 byte(s)"
  """
  def serialize_first_error(errors) do
    {field, {message, opts}} = List.first(errors)

    formatted_message =
      Enum.reduce(opts, message, fn {key, value}, acc ->
        placeholder = "%{#{key}}"

        if String.contains?(acc, placeholder) do
          String.replace(acc, placeholder, to_string(value))
        else
          acc
        end
      end)

    "#{field} #{formatted_message}"
  end
end
