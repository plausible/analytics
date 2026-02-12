defmodule PlausibleWeb.E2EController do
  use Plausible

  use PlausibleWeb, :controller

  def populate_stats(conn, %{"domain" => domain, "events" => events}) do
    site = Plausible.Repo.get_by!(Plausible.Site, domain: domain)

    events =
      events
      |> Enum.map(&deserialize/1)
      |> Enum.map(&build/1)

    stats_start_time = Enum.min_by(events, & &1.timestamp).timestamp
    stats_start_date = NaiveDateTime.to_date(stats_start_time)

    site
    |> Plausible.Site.set_native_stats_start_at(stats_start_time)
    |> Plausible.Site.set_stats_start_date(stats_start_date)
    |> Plausible.Repo.update!()

    populate(events, site)

    send_resp(conn, 200, Jason.encode!(%{"ok" => true}))
  end

  defp deserialize(event) do
    Enum.map(event, fn
      {"timestamp", value} ->
        {:timestamp, to_timestamp(value)}

      {"revenue_reporting_amount", value} ->
        {:revenue_reporting_amount, Decimal.new(value)}

      {key, value} ->
        {String.to_existing_atom(key), value}
    end)
  end

  defp build(attrs) do
    timestamp = NaiveDateTime.utc_now(:second) |> NaiveDateTime.add(-48, :hour)

    attrs =
      if attrs[:timestamp] do
        attrs
      else
        Keyword.put(attrs, :timestamp, timestamp)
      end

    Plausible.Factory.build(:event, attrs)
  end

  defp populate(events, site) do
    Plausible.TestUtils.populate_stats(site, events)
  end

  defp to_timestamp(%{"daysAgo" => offset}) do
    NaiveDateTime.utc_now(:second) |> NaiveDateTime.add(-offset, :day)
  end

  defp to_timestamp(%{"hoursAgo" => offset}) do
    NaiveDateTime.utc_now(:second) |> NaiveDateTime.add(-offset, :hour)
  end

  defp to_timestamp(%{"minutesAgo" => offset}) do
    NaiveDateTime.utc_now(:second) |> NaiveDateTime.add(-offset, :minute)
  end
end
