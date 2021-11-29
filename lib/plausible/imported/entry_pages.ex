defmodule Plausible.Imported.EntryPages do
  use Ecto.Schema
  use Plausible.ClickhouseRepo
  import Ecto.Changeset

  @primary_key false
  schema "imported_entry_pages" do
    field :domain, :string
    field :timestamp, :naive_datetime
    field :entry_page, :string
    field :visitors, :integer
  end

  def new(attrs) do
    %__MODULE__{}
    |> cast(
      attrs,
      [
        :domain,
        :timestamp,
        :entry_page,
        :visitors
      ],
      empty_values: [nil, ""]
    )
    |> validate_required([
      :domain,
      :timestamp,
      :visitors
    ])
  end
end
