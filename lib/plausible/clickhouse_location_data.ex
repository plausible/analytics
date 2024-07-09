defmodule Plausible.ClickhouseLocationData do
  @moduledoc """
  Schema for storing location id <-> translation mappins in Clickhouse
  """
  use Ecto.Schema

  @primary_key false
  schema "location_data" do
    field :type, Ch, type: "LowCardinality(String)"
    field :id, :string
    field :name, :string
  end
end