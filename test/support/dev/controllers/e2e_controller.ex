defmodule PlausibleWeb.E2EController do
  use Plausible

  on_ee do
    use PlausibleWeb, :controller

    @event_types Map.new(
                   [
                     :event,
                     :imported_visitors,
                     :imported_sources,
                     :imported_pages,
                     :imported_entry_pages,
                     :imported_exit_pages,
                     :imported_locations,
                     :imported_devices,
                     :imported_browsers,
                     :imported_operating_systems
                   ],
                   fn type ->
                     {Atom.to_string(type), type}
                   end
                 )

    def populate_stats(conn, %{"domain" => domain, "events" => events}) do
      site = Plausible.Repo.get_by!(Plausible.Site, domain: domain)

      events =
        events
        |> Enum.map(&deserialize/1)
        |> Enum.map(&build/1)
        |> maybe_set_import_id(site)

      time_fun = fn event ->
        if Map.has_key?(event, :timestamp) do
          event.timestamp
        else
          NaiveDateTime.new!(event.date, ~T[00:00:00])
        end
      end

      {stats_start_time, stats_start_date} =
        case Enum.min_by(events, time_fun, NaiveDateTime) do
          %{date: d} ->
            {NaiveDateTime.new!(d, ~T[00:00:00]), d}

          %{timestamp: ts} ->
            {ts, NaiveDateTime.to_date(ts)}
        end

      site
      |> Plausible.Site.set_native_stats_start_at(stats_start_time)
      |> Plausible.Site.set_stats_start_date(stats_start_date)
      |> Plausible.Repo.update!()

      populate(events, site)

      send_resp(conn, 200, Jason.encode!(%{"ok" => true}))
    end

    def create_funnel(conn, %{"domain" => domain, "name" => name, "steps" => steps}) do
      site = Plausible.Repo.get_by!(Plausible.Site, domain: domain)

      steps =
        Enum.map(steps, fn step ->
          goal = get_goal(site, step)
          %{"goal_id" => goal.id}
        end)

      {:ok, _} = Plausible.Funnels.create(site, name, steps)

      send_resp(conn, 200, Jason.encode!(%{"ok" => true}))
    end

    defp get_goal(site, name) do
      Plausible.Repo.get_by!(Plausible.Goal, site_id: site.id, display_name: name)
    end

    defp deserialize(event) do
      type = Map.fetch!(@event_types, event["type"] || "event")

      # to ensure relevant key atoms are in scope
      Plausible.Factory.build(type)

      attrs =
        Enum.map(event, fn
          {"timestamp", value} ->
            {:timestamp, to_timestamp(value)}

          {"date", value} ->
            {:date, to_date(value)}

          {"revenue_reporting_amount", value} ->
            {:revenue_reporting_amount, Decimal.new(value)}

          {key, value} ->
            {String.to_existing_atom(key), value}
        end)

      Keyword.put(attrs, :type, type)
    end

    defp build(attrs) do
      {type, attrs} = Keyword.pop!(attrs, :type)

      attrs =
        cond do
          type == :event and attrs[:timestamp] ->
            attrs

          type == :event and is_nil(attrs[:timestamp]) ->
            timestamp = NaiveDateTime.utc_now(:second) |> NaiveDateTime.add(-48, :hour)
            Keyword.put(attrs, :timestamp, timestamp)

          attrs[:date] ->
            attrs

          true ->
            date = Date.utc_today() |> Date.add(-2)
            Keyword.put(attrs, :date, date)
        end

      Plausible.Factory.build(type, attrs)
    end

    defp maybe_set_import_id(events, site) do
      if Enum.any?(events, &Map.has_key?(&1, :table)) do
        import = Plausible.Factory.insert(:site_import, site: site)

        Enum.map(events, &set_import_id(&1, import.id))
      else
        events
      end
    end

    defp set_import_id(%{table: _} = event, import_id) do
      Map.put(event, :import_id, import_id)
    end

    defp set_import_id(event, _import_id), do: event

    defp populate(events, site) do
      Plausible.TestUtils.populate_stats(site, events)
    end

    defp to_date(%{"daysAgo" => offset}) do
      Date.utc_today() |> Date.add(-offset)
    end

    defp to_date(d) when is_binary(d) do
      Date.from_iso8601!(d)
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

    defp to_timestamp(ts) when is_binary(ts) do
      NaiveDateTime.from_iso8601!(ts)
    end
  end
end
