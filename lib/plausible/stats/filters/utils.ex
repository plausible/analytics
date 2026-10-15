defmodule Plausible.Stats.Filters.Utils do
  @moduledoc false

  def uses_page_regex?(path), do: String.contains?(path, ["*", "|"])

  def page_regex(expr) do
    escaped =
      expr
      |> Regex.escape()
      |> String.replace("\\|", "|")
      |> String.replace("\\*\\*", ".*")
      |> String.replace("\\*", ".*")

    "^(?:#{escaped})$"
  end
end
