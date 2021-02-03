defmodule Plausible.Stats do
  use Plausible.ClickhouseRepo
  alias Plausible.Stats.Query
  @no_ref "Direct / None"

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

  @event_metrics ["visitors", "pageviews"]
  @session_metrics ["bounce_rate", "visit_duration"]

  def aggregate(site, query, metrics) do
    event_metrics = Enum.filter(metrics, &(&1 in @event_metrics))
    event_task = Task.async(fn -> aggregate_events(site, query, event_metrics) end)
    session_metrics = Enum.filter(metrics, &(&1 in @session_metrics))
    session_task = Task.async(fn -> aggregate_sessions(site, query, session_metrics) end)

    Map.merge(
      Task.await(event_task),
      Task.await(session_task)
    )
    |> Enum.map(fn {metric, value} ->
      {metric, %{value: value}}
    end)
    |> Enum.into(%{})
  end

  defp aggregate_events(_, _, []), do: %{}

  defp aggregate_events(site, query, metrics) do
    q = from(e in base_event_query(site, query), select: %{})

    Enum.reduce(metrics, q, &select_event_metric/2)
    |> ClickhouseRepo.one()
  end

  defp select_event_metric("pageviews", q) do
    from(e in q, select_merge: %{pageviews: fragment("count(*)")})
  end

  defp select_event_metric("visitors", q) do
    from(e in q, select_merge: %{visitors: fragment("uniq(?)", e.user_id)})
  end

  defp aggregate_sessions(_, _, []), do: %{}

  defp aggregate_sessions(site, query, metrics) do
    q = from(e in query_sessions(site, query), select: %{})

    Enum.reduce(metrics, q, &select_session_metric/2)
    |> ClickhouseRepo.one()
  end

  defp select_session_metric("bounce_rate", q) do
    from(s in q,
      select_merge: %{bounce_rate: fragment("round(sum(is_bounce * sign) / sum(sign) * 100)")}
    )
  end

  defp select_session_metric("visit_duration", q) do
    from(s in q, select_merge: %{visit_duration: fragment("round(avg(duration * sign))")})
  end

  @session_props [
    "source",
    "referrer",
    "utm_medium",
    "utm_source",
    "utm_campaign",
    "device",
    "browser",
    "browser_version",
    "os",
    "os_version",
    "country"
  ]

  defp base_event_query(site, query) do
    events_q = query_events(site, query)

    if Enum.any?(@session_props, &query.filters["visit:" <> &1]) do
      sessions_q =
        from(
          s in query_sessions(site, query),
          select: %{session_id: s.session_id}
        )

      from(
        e in events_q,
        join: sq in subquery(sessions_q),
        on: e.session_id == sq.session_id
      )
    else
      events_q
    end
  end

  defp query_events(site, query) do
    {first_datetime, last_datetime} = utc_boundaries(query, site.timezone)

    q =
      from(e in "events",
        where: e.domain == ^site.domain,
        where: e.timestamp >= ^first_datetime and e.timestamp < ^last_datetime
      )

    q =
      if query.filters["event:page"] do
        page = query.filters["event:page"]
        from(e in q, where: e.pathname == ^page)
      else
        q
      end

    if query.filters["props"] do
      [{key, val}] = query.filters["props"] |> Enum.into([])

      if val == "(none)" do
        from(
          e in q,
          where: fragment("not has(meta.key, ?)", ^key)
        )
      else
        from(
          e in q,
          inner_lateral_join: meta in fragment("meta as m"),
          as: :meta,
          where: meta.key == ^key and meta.value == ^val
        )
      end
    else
      q
    end
  end

  defp query_sessions(site, query) do
    {first_datetime, last_datetime} = utc_boundaries(query, site.timezone)

    sessions_q =
      from(s in "sessions",
        where: s.domain == ^site.domain,
        where: s.timestamp >= ^first_datetime and s.start < ^last_datetime
      )

    sessions_q =
      if query.filters["event:page"] do
        page = query.filters["event:page"]
        from(e in sessions_q, where: e.entry_page == ^page)
      else
        sessions_q
      end

    Enum.reduce(@session_props, sessions_q, fn prop_name, sessions_q ->
      prop_val = query.filters["visit:" <> prop_name]
      prop_name = if prop_name == "source", do: "referrer_source", else: prop_name
      prop_name = if prop_name == "device", do: "screen_size", else: prop_name
      prop_name = if prop_name == "os", do: "operating_system", else: prop_name
      prop_name = if prop_name == "os_version", do: "operating_system_version", else: prop_name
      prop_name = if prop_name == "country", do: "country_code", else: prop_name

      prop_val =
        if prop_name == "referrer_source" && prop_val == @no_ref do
          ""
        else
          prop_val
        end

      if prop_val do
        where_target = [{String.to_existing_atom(prop_name), prop_val}]
        from(s in sessions_q, where: ^where_target)
      else
        sessions_q
      end
    end)
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

  defp utc_boundaries(%Query{date_range: date_range}, timezone) do
    {:ok, first} = NaiveDateTime.new(date_range.first, ~T[00:00:00])

    first_datetime =
      Timex.to_datetime(first, timezone)
      |> Timex.Timezone.convert("UTC")

    {:ok, last} = NaiveDateTime.new(date_range.last |> Timex.shift(days: 1), ~T[00:00:00])

    last_datetime =
      Timex.to_datetime(last, timezone)
      |> Timex.Timezone.convert("UTC")

    {first_datetime, last_datetime}
  end
end
