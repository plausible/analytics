defmodule Plausible.Ecto.Types.NanoidBase do
  @moduledoc """
  Base module for nanoid string types
  """

  use Ecto.Type

  def type(), do: :string

  def cast(value) when is_binary(value), do: {:ok, value}
  def cast(_), do: :error

  def load(value), do: {:ok, value}

  def dump(value) when is_binary(value), do: {:ok, value}
  def dump(_), do: :error

  @callback autogenerate() :: String.t()
end

defmodule Plausible.Ecto.Types.Nanoid do
  @moduledoc """
  Custom column type for nanoid strings
  """

  @behaviour Plausible.Ecto.Types.NanoidBase

  def type(), do: Plausible.Ecto.Types.NanoidBase.type()
  def cast(value), do: Plausible.Ecto.Types.NanoidBase.cast(value)
  def load(value), do: Plausible.Ecto.Types.NanoidBase.load(value)
  def dump(value), do: Plausible.Ecto.Types.NanoidBase.dump(value)

  @spec autogenerate() :: String.t()
  def autogenerate(), do: Nanoid.generate()
end

defmodule Plausible.Ecto.Types.TrackerScriptNanoid do
  @moduledoc """
  Custom column type for tracker script configuration nanoid strings with pa- prefix
  """

  @behaviour Plausible.Ecto.Types.NanoidBase

  def type(), do: Plausible.Ecto.Types.NanoidBase.type()
  def cast(value), do: Plausible.Ecto.Types.NanoidBase.cast(value)
  def load(value), do: Plausible.Ecto.Types.NanoidBase.load(value)
  def dump(value), do: Plausible.Ecto.Types.NanoidBase.dump(value)

  @spec autogenerate() :: String.t()
  def autogenerate(), do: "pa-#{Nanoid.generate()}"
end
