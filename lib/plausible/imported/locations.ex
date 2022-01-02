defmodule Plausible.Imported.Locations do
  use Ecto.Schema
  use Plausible.ClickhouseRepo
  import Ecto.Changeset

  @primary_key false
  schema "imported_locations" do
    field :domain, :string
    field :timestamp, :naive_datetime
    field :country, :string, default: ""
    field :region, :string, default: ""
    field :city, :integer, default: 0
    field :visitors, :integer
  end

  def new(attrs) do
    %__MODULE__{}
    |> cast(
      attrs,
      [
        :domain,
        :timestamp,
        :country,
        :region,
        :city,
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
