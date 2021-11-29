defmodule Plausible.Imported.Browsers do
  use Ecto.Schema
  use Plausible.ClickhouseRepo
  import Ecto.Changeset

  @primary_key false
  schema "imported_utm_mediums" do
    field :domain, :string
    field :timestamp, :naive_datetime
    field :browser, :string
    field :version, :string
    field :visitors, :integer
  end

  def new(attrs) do
    %__MODULE__{}
    |> cast(
      attrs,
      [
        :domain,
        :timestamp,
        :browser,
        :versions,
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
