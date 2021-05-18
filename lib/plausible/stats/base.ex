defmodule Plausible.Stats.Base do
  use Plausible.ClickhouseRepo
  alias Plausible.Stats.Query

  @no_ref "Direct / None"
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

  def base_event_query(site, query) do
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

  def query_events(site, query) do
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

    q =
      if query.filters["event:name"] do
        name = query.filters["event:name"]
        from(e in q, where: e.name == ^name)
      else
        q
      end

    Enum.reduce(query.filters, q, fn {filter_key, filter_value}, query ->
      case filter_key do
        "event:props:" <> prop_name ->
          if filter_value == "(none)" do
            from(
              e in query,
              where: fragment("not has(meta.key, ?)", ^prop_name)
            )
          else
            from(
              e in query,
              inner_lateral_join: meta in "meta",
              as: :meta,
              where: meta.key == ^prop_name and meta.value == ^filter_value
            )
          end

        _ ->
          query
      end
    end)
  end

  def query_sessions(site, query) do
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
