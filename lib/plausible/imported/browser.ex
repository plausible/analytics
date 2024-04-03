defmodule Plausible.Imported.Browser do
  @moduledoc false
  use Ecto.Schema

  @primary_key false
  schema "imported_browsers" do
    field :site_id, Ch, type: "UInt64"
    field :import_id, Ch, type: "UInt64"
    field :date, :date
    field :browser, :string
    field :browser_version, :string
    field :visitors, Ch, type: "UInt64"
    field :visits, Ch, type: "UInt64"
    field :visit_duration, Ch, type: "UInt64"
    field :pageviews, Ch, type: "UInt64"
    field :bounces, Ch, type: "UInt32"
  end
end
