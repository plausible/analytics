defmodule Plausible.Imported.Locations do
  use Ecto.Schema
  use Plausible.ClickhouseRepo
  import Ecto.Changeset

  @primary_key false
  schema "imported_locations" do
    field :site_id, :integer
    field :timestamp, :naive_datetime
    field :country, :string, default: ""
    field :region, :string, default: ""
    field :city, :integer, default: 0
    field :visitors, :integer
    field :visits, :integer
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
        :country,
        :region,
        :city,
        :visitors,
        :visits,
        :bounces,
        :visit_duration
      ],
      empty_values: [nil, ""]
    )
    |> validate_required([
      :site_id,
      :timestamp,
      :visitors,
      :visits,
      :bounces,
      :visit_duration
    ])
  end
end
