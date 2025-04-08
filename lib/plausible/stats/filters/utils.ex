defmodule Plausible.Stats.Filters.Utils do
  @moduledoc false

  def page_regex(expr) do
    escaped =
      expr
      |> Regex.escape()
      |> String.replace("\\|", "|")
      |> String.replace("\\*\\*", ".*")
      |> String.replace("\\*", ".*")

    "^#{escaped}$"
  end
end
