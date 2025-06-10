defmodule Plausible.Billing.Ecto.Feature do
  @moduledoc """
  Ecto type representing a feature. Features are cast and stored in the
  database as strings and loaded as modules, for example: `"props"` is loaded
  as `Plausible.Billing.Feature.Props`.
  """

  use Ecto.Type

  def type, do: :string

  def cast(feature) when is_binary(feature) do
    found =
      Enum.find(Plausible.Billing.Feature.list(), fn mod ->
        Atom.to_string(mod.name()) == feature
      end)

    if found, do: {:ok, found}, else: :error
  end

  def cast(mod) when is_atom(mod) do
    {:ok, mod}
  end

  def load(feature) when is_binary(feature) do
    cast(feature)
  end

  def dump(mod) when is_atom(mod) do
    {:ok, Atom.to_string(mod.name())}
  end
end
