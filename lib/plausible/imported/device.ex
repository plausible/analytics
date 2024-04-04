defmodule Plausible.Imported.Device do
  @moduledoc false
  use Ecto.Schema

  @primary_key false
  schema "imported_devices" do
    field :site_id, Ch, type: "UInt64"
    field :import_id, Ch, type: "UInt64"
    field :date, :date
    field :device, :string
    field :visitors, Ch, type: "UInt64"
    field :visits, Ch, type: "UInt64"
    field :visit_duration, Ch, type: "UInt64"
    field :pageviews, Ch, type: "UInt64"
    field :bounces, Ch, type: "UInt32"
  end
end
