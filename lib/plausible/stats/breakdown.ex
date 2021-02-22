defmodule Plausible.Stats.Breakdown do
  use Plausible.ClickhouseRepo
  import Plausible.Stats.Base

  @event_metrics ["visitors", "pageviews"]
  @session_metrics ["bounce_rate", "visit_duration"]

  # use join once this is solved: https://github.com/ClickHouse/ClickHouse/issues/10276
  # https://github.com/ClickHouse/ClickHouse/issues/17319
  def breakdown(site, query, "event:page", metrics, pagination) do
    event_metrics = Enum.filter(metrics, &(&1 in @event_metrics))
    session_metrics = Enum.filter(metrics, &(&1 in @session_metrics))

    event_result = breakdown_events(site, query, event_metrics, pagination)
    pages = Enum.map(event_result, fn r -> r[:page] end)

    if Enum.any?(session_metrics) do
      session_result =
        from(s in query_sessions(site, query),
          group_by: s.entry_page,
          where: s.entry_page in ^pages,
          select: %{entry_page: s.entry_page}
        )
        |> select_metrics(session_metrics)
        |> ClickhouseRepo.all()

      session_metrics_atoms = Enum.map(session_metrics, &String.to_atom/1)

      Enum.map(event_result, fn row ->
        session_row = Enum.find(session_result, fn row2 -> row2[:entry_page] == row[:page] end)
        Map.merge(row, Map.take(session_row, session_metrics_atoms))
      end)
    else
      event_result
    end
  end

  def breakdown(_, _, _, [], _), do: %{}

  def breakdown(site, query, property, metrics, {limit, page}) do
    offset = (page - 1) * limit

    from(s in query_sessions(site, query),
      order_by: [desc: fragment("uniq(?)", s.user_id), asc: fragment("min(?)", s.start)],
      limit: ^limit,
      offset: ^offset,
      select: %{}
    )
    |> do_group_by(property)
    |> select_metrics(metrics)
    |> ClickhouseRepo.all()
  end

  defp breakdown_events(_, _, [], _), do: %{}

  defp breakdown_events(site, query, metrics, {limit, page}) do
    offset = (page - 1) * limit

    from(e in base_event_query(site, query),
      group_by: e.pathname,
      order_by: [desc: fragment("uniq(?)", e.user_id)],
      limit: ^limit,
      offset: ^offset,
      select: %{page: e.pathname}
    )
    |> select_event_metrics(metrics)
    |> ClickhouseRepo.all()
  end

  defp do_group_by(q, "visit:source") do
    from(
      s in q,
      group_by: s.referrer_source,
      select_merge: %{source: s.referrer_source}
    )
  end

  defp do_group_by(q, "visit:country") do
    from(
      s in q,
      group_by: s.country_code,
      select_merge: %{country: s.country_code}
    )
  end

  defp do_group_by(q, "visit:entry_page") do
    from(
      s in q,
      group_by: s.entry_page,
      select_merge: %{entry_page: s.entry_page}
    )
  end

  defp do_group_by(q, "visit:referrer") do
    from(
      s in q,
      group_by: s.referrer,
      select_merge: %{referrer: s.referrer}
    )
  end

  defp do_group_by(q, "visit:utm_medium") do
    from(
      s in q,
      group_by: s.utm_medium,
      select_merge: %{utm_medium: s.utm_medium}
    )
  end

  defp do_group_by(q, "visit:utm_source") do
    from(
      s in q,
      group_by: s.utm_source,
      select_merge: %{utm_source: s.utm_source}
    )
  end

  defp do_group_by(q, "visit:utm_campaign") do
    from(
      s in q,
      group_by: s.utm_campaign,
      select_merge: %{utm_campaign: s.utm_campaign}
    )
  end

  defp do_group_by(q, "visit:device") do
    from(
      s in q,
      group_by: s.screen_size,
      select_merge: %{device: s.screen_size}
    )
  end

  defp do_group_by(q, "visit:os") do
    from(
      s in q,
      group_by: s.operating_system,
      select_merge: %{os: s.operating_system}
    )
  end

  defp do_group_by(q, "visit:os_version") do
    from(
      s in q,
      group_by: s.operating_system_version,
      select_merge: %{os_version: s.operating_system_version}
    )
  end

  defp do_group_by(q, "visit:browser") do
    from(
      s in q,
      group_by: s.browser,
      select_merge: %{browser: s.browser}
    )
  end

  defp do_group_by(q, "visit:browser_version") do
    from(
      s in q,
      group_by: s.browser_version,
      select_merge: %{browser_version: s.browser_version}
    )
  end

  defp select_event_metrics(q, []), do: q

  defp select_event_metrics(q, ["pageviews" | rest]) do
    from(e in q,
      select_merge: %{pageviews: fragment("countIf(? = 'pageview')", e.name)}
    )
    |> select_event_metrics(rest)
  end

  defp select_event_metrics(q, ["visitors" | rest]) do
    from(e in q,
      select_merge: %{visitors: fragment("uniq(?) as count", e.user_id)}
    )
    |> select_event_metrics(rest)
  end

  defp select_metrics(q, []), do: q

  defp select_metrics(q, ["pageviews" | rest]) do
    from(s in q,
      select_merge: %{pageviews: fragment("sum(? * ?)", s.sign, s.pageviews)}
    )
    |> select_metrics(rest)
  end

  defp select_metrics(q, ["visitors" | rest]) do
    from(s in q,
      select_merge: %{visitors: fragment("uniq(?) as count", s.user_id)}
    )
    |> select_metrics(rest)
  end

  defp select_metrics(q, ["bounce_rate" | rest]) do
    from(s in q,
      select_merge: %{
        bounce_rate: fragment("round(sum(? * ?) / sum(?) * 100)", s.is_bounce, s.sign, s.sign)
      }
    )
    |> select_metrics(rest)
  end

  defp select_metrics(q, ["visit_duration" | rest]) do
    from(s in q,
      select_merge: %{visit_duration: fragment("round(avg(? * ?))", s.duration, s.sign)}
    )
    |> select_metrics(rest)
  end
end
