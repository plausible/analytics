defmodule Plausible.Site.InstallationMeta do
  @moduledoc """
  Embedded schema for installation meta-data
  """
  use Ecto.Schema

  @type t() :: %__MODULE__{}

  embedded_schema do
    field :installation_type, :string, default: "manual"
    field :script_config, :map, default: %{}
  end
end
