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
      case query.filters["event:page"] do
        {:is, page} -> from(e in q, where: e.pathname == ^page)
        {:member, list} -> from(e in q, where: e.pathname in ^list)
        _ -> q
      end

    q =
      case query.filters["event:name"] do
        {:is, name} -> from(e in q, where: e.name == ^name)
        {:member, list} -> from(e in q, where: e.name in ^list)
        _ -> q
      end

    Enum.reduce(query.filters, q, fn {filter_key, filter_value}, query ->
      case filter_key do
        "event:props:" <> prop_name ->
          filter_value = elem(filter_value, 1)

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

  @api_prop_name_to_db %{
    "source" => "referrer_source",
    "device" => "screen_size",
    "os" => "operating_system",
    "os_version" => "operating_system_version",
    "country" => "country_code"
  }

  def query_sessions(site, query) do
    {first_datetime, last_datetime} = utc_boundaries(query, site.timezone)

    sessions_q =
      from(s in "sessions",
        where: s.domain == ^site.domain,
        where: s.timestamp >= ^first_datetime and s.start < ^last_datetime
      )

    sessions_q =
      if query.filters["event:page"] do
        case query.filters["event:page"] do
          {:is, page} ->
            from(e in sessions_q, where: e.entry_page == ^page)

          {:member, list} ->
            from(e in sessions_q, where: e.entry_page in ^list)
        end
      else
        sessions_q
      end

    Enum.reduce(@session_props, sessions_q, fn prop_name, sessions_q ->
      filter = query.filters["visit:" <> prop_name]
      prop_name = Map.get(@api_prop_name_to_db, prop_name, prop_name)

      case filter do
        {:is, value} ->
          where_target = [{String.to_existing_atom(prop_name), db_prop_val(prop_name, value)}]
          from(s in sessions_q, where: ^where_target)

        {:member, values} ->
          list = Enum.map(values, &db_prop_val(prop_name, &1))
          fragment_data = [{String.to_existing_atom(prop_name), {:in, list}}]
          from(s in sessions_q, where: fragment(^fragment_data))

        _ ->
          sessions_q
      end
    end)
  end

  defp db_prop_val("referrer_source", @no_ref), do: ""
  defp db_prop_val(_, val), do: val

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
