defmodule Plausible.Imported.ExitPage do
  @moduledoc false
  use Ecto.Schema

  @primary_key false
  schema "imported_exit_pages" do
    field :site_id, Ch, type: "UInt64"
    field :date, :date
    field :exit_page, :string
    field :visitors, Ch, type: "UInt64"
    field :exits, Ch, type: "UInt64"
  end
end
