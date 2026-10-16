defmodule Plausible.Stats.Filters.Utils do
  @moduledoc false

  def uses_page_regex?(path), do: String.contains?(path, ["*", "|"])

  # Preserve escaped pipes until each alternative is converted to a regex.
  def split_page_patterns(expr), do: String.split(expr, ~r/(?<!\\)\|/)

  def page_regex(expr) do
    escaped =
      expr
      |> split_page_patterns()
      |> Enum.map_join("|", fn pattern ->
        pattern
        |> String.replace("\\|", "|")
        |> Regex.escape()
        |> String.replace("\\*\\*", ".*")
        |> String.replace("\\*", ".*")
      end)

    "^(?:#{escaped})$"
  end
end
