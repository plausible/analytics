defmodule Plausible.Imported.OperatingSystems do
  use Ecto.Schema
  use Plausible.ClickhouseRepo
  import Ecto.Changeset

  @primary_key false
  schema "imported_operating_systems" do
    field :site_id, :integer
    field :timestamp, :naive_datetime
    field :operating_system, :string
    field :visitors, :integer
  end

  def new(attrs) do
    %__MODULE__{}
    |> cast(
      attrs,
      [
        :site_id,
        :timestamp,
        :operating_system,
        :visitors
      ],
      empty_values: [nil, ""]
    )
    |> validate_required([
      :site_id,
      :timestamp,
      :visitors
    ])
  end
end
