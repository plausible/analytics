defmodule Plausible.Stats.Timeseries do
  use Plausible.ClickhouseRepo
  alias Plausible.Stats.Query
  import Plausible.Stats.Base

  def timeseries(site, query) do
    steps = buckets(query)

    groups =
      from(e in base_event_query(site, query),
        group_by: fragment("bucket"),
        order_by: fragment("bucket")
      )
      |> select_bucket(site, query)
      |> ClickhouseRepo.all()
      |> Enum.into(%{})

    plot = Enum.map(steps, fn step -> groups[step] || 0 end)
    labels = Enum.map(steps, fn step -> Timex.format!(step, "{ISOdate}") end)

    {plot, labels}
  end

  defp buckets(%Query{interval: "month"} = query) do
    n_buckets = Timex.diff(query.date_range.last, query.date_range.first, :months)

    Enum.map(n_buckets..0, fn shift ->
      query.date_range.last
      |> Timex.beginning_of_month()
      |> Timex.shift(months: -shift)
    end)
  end

  defp buckets(%Query{interval: "date"} = query) do
    Enum.into(query.date_range, [])
  end

  defp select_bucket(q, site, %Query{interval: "month"}) do
    from(
      e in q,
      select:
        {fragment("toStartOfMonth(toTimeZone(?, ?)) as bucket", e.timestamp, ^site.timezone),
         fragment("uniq(?)", e.user_id)}
    )
  end

  defp select_bucket(q, site, %Query{interval: "date"}) do
    from(
      e in q,
      select:
        {fragment("toDate(toTimeZone(?, ?)) as bucket", e.timestamp, ^site.timezone),
         fragment("uniq(?)", e.user_id)}
    )
  end
end
