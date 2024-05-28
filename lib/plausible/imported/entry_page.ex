defmodule Plausible.Imported.EntryPage do
  @moduledoc false
  use Ecto.Schema

  @primary_key false
  schema "imported_entry_pages" do
    field :site_id, Ch, type: "UInt64"
    field :import_id, Ch, type: "UInt64"
    field :date, :date
    field :entry_page, :string
    field :visitors, Ch, type: "UInt64"
    field :entrances, Ch, type: "UInt64"
    field :visit_duration, Ch, type: "UInt64"
    field :pageviews, Ch, type: "UInt64"
    field :bounces, Ch, type: "UInt32"
  end
end
