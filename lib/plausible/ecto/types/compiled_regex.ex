defmodule Plausible.Ecto.Types.CompiledRegex do
  @moduledoc """
  Ensures that the regex is compiled on load
  """
  use Ecto.Type

  def type, do: :string

  def cast(val) when is_binary(val), do: {:ok, val}
  def cast(_), do: :error

  def load(val), do: {:ok, Regex.compile!(val)}
  def dump(val), do: {:ok, val}
end
