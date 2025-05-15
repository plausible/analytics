defmodule Plausible.Ecto.Types.Nanoid do
  @moduledoc """
  Custom column type for nanoid strings
  """

  use Ecto.Type

  def type(), do: :string

  def cast(value) when is_binary(value), do: {:ok, value}
  def cast(_), do: :error

  def load(value), do: {:ok, value}

  def dump(value) when is_binary(value), do: {:ok, value}
  def dump(_), do: :error

  @spec autogenerate() :: String.t()
  def autogenerate(), do: Nanoid.generate()
end
