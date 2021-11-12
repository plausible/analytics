defmodule Plausible.Imported.Visitors do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "imported_visitors" do
    field :domain, :string
    field :date, :naive_datetime
    field :visitors, :integer
    field :pageviews, :integer
    field :bounce_rate, :integer
    field :avg_visit_duration, :integer
  end

  def new(attrs) do
    %__MODULE__{}
    |> cast(
      attrs,
      [
        :domain,
        :date,
        :visitors,
        :pageviews,
        :bounce_rate,
        :avg_visit_duration
      ],
      empty_values: [nil, ""]
    )
    |> validate_required([
      :domain,
      :date,
      :visitors,
      :pageviews,
      :bounce_rate,
      :avg_visit_duration
    ])
  end
end
