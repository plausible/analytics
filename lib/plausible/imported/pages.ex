defmodule Plausible.Imported.Pages do
  use Ecto.Schema
  use Plausible.ClickhouseRepo
  import Ecto.Changeset

  @primary_key false
  schema "imported_pages" do
    field :domain, :string
    field :timestamp, :naive_datetime
    field :page, :string
    field :visitors, :integer
    field :pageviews, :integer
    field :time_on_page, :integer
  end

  def new(attrs) do
    %__MODULE__{}
    |> cast(
      attrs,
      [
        :domain,
        :timestamp,
        :page,
        :visitors,
        :pageviews,
        :time_on_page
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
