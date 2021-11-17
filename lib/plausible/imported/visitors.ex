defmodule Plausible.Imported.Visitors do
  use Ecto.Schema
  use Plausible.ClickhouseRepo
  import Ecto.Changeset
  alias Plausible.Stats

  @primary_key false
  schema "imported_visitors" do
    field :domain, :string
    field :timestamp, :naive_datetime
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
        :timestamp,
        :visitors,
        :pageviews,
        :bounce_rate,
        :avg_visit_duration
      ],
      empty_values: [nil, ""]
    )
    |> validate_required([
      :domain,
      :timestamp,
      :visitors,
      :pageviews,
      :bounce_rate,
      :avg_visit_duration
    ])
  end

  def from_google_analytics(domain, %{
        "dimensions" => [timestamp],
        "metrics" => [%{"values" => values}]
      }) do
    [visitors, pageviews, bounce_rate, avg_session_duration] =
      values
      |> Enum.map(&Integer.parse/1)
      |> Enum.map(&elem(&1, 0))

    {year, monthday} = String.split_at(timestamp, 4)
    {month, day} = String.split_at(monthday, 2)

    datetime =
      [year, month, day]
      |> Enum.map(&Kernel.elem(Integer.parse(&1), 0))
      |> List.to_tuple()
      |> (&NaiveDateTime.from_erl!({&1, {12, 0, 0}})).()

    new(%{
      domain: domain,
      timestamp: datetime,
      visitors: visitors,
      pageviews: pageviews,
      bounce_rate: bounce_rate,
      avg_visit_duration: avg_session_duration
    })
  end

  def timeseries(site, query) do
    {first_datetime, last_datetime} = Stats.Base.utc_boundaries(query, site.timezone)

    result =
      from(v in "imported_visitors",
        group_by: fragment("date"),
        where: v.domain == ^site.domain,
        where: v.timestamp >= ^first_datetime and v.timestamp < ^last_datetime,
        select: %{"visitors" => sum(v.visitors)}
      )
      |> Stats.Timeseries.select_bucket(site, query)
      |> ClickhouseRepo.all()
      |> Enum.map(fn row -> {row["date"], row["visitors"]} end)
      |> Map.new()

    Stats.Timeseries.buckets(query)
    |> Enum.map(fn step -> Map.get(result, step, 0) end)
  end
end
