defmodule Plausible.Imported.Page do
  @moduledoc false
  use Ecto.Schema

  @primary_key false
  schema "imported_pages" do
    field :site_id, Ch, type: "UInt64"
    field :date, :date
    field :hostname, :string
    field :page, :string
    field :visitors, Ch, type: "UInt64"
    field :pageviews, Ch, type: "UInt64"
    field :exits, Ch, type: "UInt64"
    field :time_on_page, Ch, type: "UInt64"
  end
end
