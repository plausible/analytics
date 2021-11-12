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

  def from_google_analytics(domain, %{
        "dimensions" => [date],
        "metrics" => [%{"values" => values}]
      }) do
    [visitors, pageviews, bounce_rate, avg_session_duration] =
      values
      |> Enum.map(&Integer.parse/1)
      |> Enum.map(&elem(&1, 0))

    {year, monthday} = String.split_at(date, 4)
    {month, day} = String.split_at(monthday, 2)

    datetime =
      [year, month, day]
      |> Enum.map(&Kernel.elem(Integer.parse(&1), 0))
      |> List.to_tuple()
      |> (&NaiveDateTime.from_erl!({&1, {12, 0, 0}})).()

    new(%{
      domain: domain,
      date: datetime,
      visitors: visitors,
      pageviews: pageviews,
      bounce_rate: bounce_rate,
      avg_visit_duration: avg_session_duration
    })
  end
end
