defmodule Plausible.Stats do
  use Plausible.ClickhouseRepo
  alias Plausible.Stats.Query
  @no_ref "Direct / None"

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

  def timeseries(site, query) do
    steps = buckets(query)

    groups =
      from(e in base_query(site, query),
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

  defp base_query(site, query) do
    {first_datetime, last_datetime} = utc_boundaries(query, site.timezone)

    sessions_q =
      from(s in "sessions",
        where: s.domain == ^site.domain,
        where: s.timestamp >= ^first_datetime and s.start < ^last_datetime,
        select: %{session_id: s.session_id}
      )

    sessions_q =
      Enum.reduce(@session_props, sessions_q, fn prop_name, sessions_q ->
        prop_val = query.filters["session:" <> prop_name]
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

    q =
      from(e in "events",
        where: e.domain == ^site.domain,
        where: e.timestamp >= ^first_datetime and e.timestamp < ^last_datetime
      )

    q =
      if Enum.any?(@session_props, &query.filters["session:" <> &1]) do
        from(
          e in q,
          join: sq in subquery(sessions_q),
          on: e.session_id == sq.session_id
        )
      else
        q
      end

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
