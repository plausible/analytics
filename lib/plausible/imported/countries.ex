defmodule Plausible.Imported.Countries do
  use Ecto.Schema
  use Plausible.ClickhouseRepo
  import Ecto.Changeset

  @primary_key false
  schema "imported_countries" do
    field :domain, :string
    field :timestamp, :naive_datetime
    field :country, :string
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
