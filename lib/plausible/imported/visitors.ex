defmodule Plausible.Imported.Visitors do
  use Ecto.Schema
  use Plausible.ClickhouseRepo
  import Ecto.Changeset

  @primary_key false
  schema "imported_visitors" do
    field :domain, :string
    field :timestamp, :naive_datetime
    field :visitors, :integer
    field :pageviews, :integer
    field :bounces, :integer
    field :visits, :integer
    # Sum total
    field :visit_duration, :integer
  end

  def new(attrs) do
    %__MODULE__{}
    |> cast(
      attrs,
      [
        :domain,
        :timestamp,
        :visitors,
        :pageviews,
        :bounces,
        :visits,
        :visit_duration
      ],
      empty_values: [nil, ""]
    )
    |> validate_required([
      :domain,
      :timestamp,
      :visitors,
      :pageviews,
      :bounces,
      :visits,
      :visit_duration
    ])
  end
end
