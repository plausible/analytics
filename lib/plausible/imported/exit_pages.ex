defmodule Plausible.Imported.ExitPages do
  use Ecto.Schema
  use Plausible.ClickhouseRepo
  import Ecto.Changeset

  @primary_key false
  schema "imported_exit_pages" do
    field :site_id, :integer
    field :timestamp, :date
    field :exit_page, :string
    field :visitors, :integer
    field :exits, :integer
  end

  def new(attrs) do
    %__MODULE__{}
    |> cast(
      attrs,
      [
        :site_id,
        :timestamp,
        :exit_page,
        :visitors,
        :exits
      ],
      empty_values: [nil, ""]
    )
    |> validate_required([
      :site_id,
      :timestamp,
      :exit_page,
      :visitors,
      :exits
    ])
  end
end
