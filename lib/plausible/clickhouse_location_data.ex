defmodule Plausible.ClickhouseLocationData do
  @moduledoc """
  Schema for storing location id <-> translation mappings in ClickHouse

  Indirectly read via dictionary `location_data_dictionary` in ALIAS columns in
  `events_v2`, `sessions_v2` and `imported_locations` table.
  """
  use Ecto.Schema

  @primary_key false
  schema "location_data" do
    field :type, Ch, type: "LowCardinality(String)"
    field :id, :string
    field :name, :string
  end
end
