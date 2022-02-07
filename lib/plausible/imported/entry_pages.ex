defmodule Plausible.Imported.EntryPages do
  use Ecto.Schema
  use Plausible.ClickhouseRepo
  import Ecto.Changeset

  @primary_key false
  schema "imported_entry_pages" do
    field :site_id, :integer
    field :timestamp, :date
    field :entry_page, :string
    field :visitors, :integer
    field :entrances, :integer
    field :bounces, :integer
    # Sum total
    field :visit_duration, :integer
  end

  def new(attrs) do
    %__MODULE__{}
    |> cast(
      attrs,
      [
        :site_id,
        :timestamp,
        :entry_page,
        :visitors,
        :entrances,
        :bounces,
        :visit_duration
      ],
      empty_values: [nil, ""]
    )
    |> validate_required([
      :site_id,
      :timestamp,
      :entry_page,
      :visitors,
      :entrances,
      :bounces,
      :visit_duration
    ])
  end
end
