defmodule Plausible.Imported.CustomEvent do
  @moduledoc false
  use Ecto.Schema

  @primary_key false
  schema "imported_custom_events" do
    field :site_id, Ch, type: "UInt64"
    field :import_id, Ch, type: "UInt64"
    field :date, :date
    field :name, :string
    field :link_url, :string
    field :path, :string
    field :visitors, Ch, type: "UInt64"
    field :events, Ch, type: "UInt64"
  end
end
