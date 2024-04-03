defmodule Plausible.Imported.ExitPage do
  @moduledoc false
  use Ecto.Schema

  @primary_key false
  schema "imported_exit_pages" do
    field :site_id, Ch, type: "UInt64"
    field :import_id, Ch, type: "UInt64"
    field :date, :date
    field :exit_page, :string
    field :exits, Ch, type: "UInt64"
    field :visitors, Ch, type: "UInt64"
    field :visit_duration, Ch, type: "UInt64"
    field :pageviews, Ch, type: "UInt64"
    field :bounces, Ch, type: "UInt32"
  end
end
