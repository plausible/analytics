defmodule Plausible.Stats.Sql.Util do
  @moduledoc false

  import Ecto.Query

  @doc """
  Utility for joining a list of `Ecto.Query.dynamic` expressions with a logical or
  """
  def or_join(clauses) when is_list(clauses) do
    Enum.reduce(clauses, false, fn clause, dynamic_statement ->
      dynamic([e], ^clause or ^dynamic_statement)
    end)
  end
end
