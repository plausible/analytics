defmodule Plausible.Stats.Clickhouse do
  @moduledoc """
    Clickhouse utility functions
  """

  use Plausible
  use Plausible.Repo
  use Plausible.ClickhouseRepo
  use Plausible.Stats.SQL.Fragments

  import Ecto.Query, only: [from: 2, subquery: 1]

  alias Plausible.Timezones
  alias Plausible.Stats

  @spec pageview_start_date_local(Plausible.Site.t()) :: Date.t() | nil
  def pageview_start_date_local(site) do
    datetime =
      ClickhouseRepo.one(
        from(e in "events_v2",
          select: fragment("min(?)", e.timestamp),
          where: e.site_id == ^site.id,
          where: e.timestamp >= ^site.native_stats_start_at
        )
      )

    case datetime do
      # no stats for this domain yet
      ~N[1970-01-01 00:00:00] ->
        nil

      _ ->
        Timezones.to_date_in_timezone(datetime, site.timezone)
    end
  end

  def imported_pageview_count(site) do
    Plausible.ClickhouseRepo.one(
      from(i in "imported_visitors",
        where: i.site_id == ^site.id,
        select: sum(i.pageviews)
      )
    )
  end

  @spec imported_pageview_counts(Plausible.Site.t()) :: %{non_neg_integer() => non_neg_integer()}
  def imported_pageview_counts(site) do
    from(i in "imported_visitors",
      where: i.site_id == ^site.id,
      group_by: i.import_id,
      select: {i.import_id, sum(i.pageviews)}
    )
    |> Plausible.ClickhouseRepo.all()
    |> Map.new()
  end

  def usage_breakdown([sid | _] = site_ids, date_range) when is_integer(sid) do
    Enum.chunk_every(site_ids, 1000)
    |> Enum.map(fn site_ids ->
      fn ->
        ClickhouseRepo.one(
          from(e in "events_v2",
            where: e.site_id in ^site_ids,
            where: e.name != "engagement",
            where: fragment("toDate(?)", e.timestamp) >= ^date_range.first,
            where: fragment("toDate(?)", e.timestamp) <= ^date_range.last,
            select: {
              fragment("countIf(? = 'pageview')", e.name),
              fragment("countIf(? != 'pageview')", e.name)
            }
          )
        )
      end
    end)
    |> ClickhouseRepo.parallel_tasks(max_concurrency: 10)
    |> Enum.reduce(fn {pageviews, custom_events}, {pageviews_total, custom_events_total} ->
      {pageviews_total + pageviews, custom_events_total + custom_events}
    end)
  end

  def usage_breakdown([], _date_range), do: {0, 0}

  @doc """
  Estimates a team's monthly traffic from a partial sample, computed entirely in
  ClickHouse with one light query scoped to the team's own sites. Used by
  `Plausible.Workers.ScoreTrialProspects`.

  Billable events = pageviews + custom events (everything except engagement).
  The window is the trailing `@window_days` complete days (up to yesterday).
  Within it, `min(toDate(timestamp))` is the team's `first_data_day`, so the
  elapsed complete days since then give `observed_days` (clamped to
  `[1, @window_days]`), and the monthly figure is
  `round(events_in_window / observed_days * @days_in_month)` — all in the DB.

  Returns `%{first_data_day, events_in_window, observed_days, estimated_monthly}`.
  `events_in_window == 0` means the team had no complete day of traffic.
  """
  # trailing complete days sampled to estimate the monthly run rate
  @window_days 30
  @days_in_month 30
  @spec trial_traffic([pos_integer()]) :: %{
          first_data_day: Date.t() | nil,
          events_in_window: non_neg_integer(),
          observed_days: non_neg_integer(),
          estimated_monthly: non_neg_integer()
        }
  def trial_traffic([]) do
    %{first_data_day: nil, events_in_window: 0, observed_days: 0, estimated_monthly: 0}
  end

  def trial_traffic(site_ids) do
    last_complete_day = Date.add(Date.utc_today(), -1)
    first_day = Date.add(last_complete_day, -(@window_days - 1))

    aggregates =
      from(e in "events_v2",
        where: e.site_id in ^site_ids,
        where: e.name != "engagement",
        where: fragment("toDate(?)", e.timestamp) >= ^first_day,
        where: fragment("toDate(?)", e.timestamp) <= ^last_complete_day,
        select: %{
          first_data_day: fragment("min(toDate(?))", e.timestamp),
          events_in_window: fragment("count(*)"),
          # elapsed complete days since first traffic, clamped to [1, @window_days]
          observed_days:
            fragment(
              "least(greatest(dateDiff('day', min(toDate(?)), ?) + 1, 1), ?)",
              e.timestamp,
              ^last_complete_day,
              ^@window_days
            )
        }
      )

    ClickhouseRepo.one(
      from(t in subquery(aggregates),
        select: %{
          first_data_day: t.first_data_day,
          events_in_window: t.events_in_window,
          observed_days: t.observed_days,
          estimated_monthly:
            fragment(
              "toUInt64(round(? / ? * ?))",
              t.events_in_window,
              t.observed_days,
              ^@days_in_month
            )
        }
      )
    )
  end

  def per_site_usage_breakdown(
        site_ids,
        date_range,
        limit \\ Plausible.Teams.Billing.max_sites_for_usage_breakdown()
      )

  def per_site_usage_breakdown([], _date_range, _limit), do: []

  def per_site_usage_breakdown(
        [sid | _] = site_ids,
        date_range,
        limit
      )
      when is_integer(sid) and length(site_ids) <= limit do
    ClickhouseRepo.all(
      from(e in "events_v2",
        where: e.site_id in ^site_ids,
        where: e.name != "engagement",
        where: fragment("toDate(?)", e.timestamp) >= ^date_range.first,
        where: fragment("toDate(?)", e.timestamp) <= ^date_range.last,
        group_by: e.site_id,
        order_by: [
          desc: fragment("countIf(? = 'pageview') + countIf(? != 'pageview')", e.name, e.name)
        ],
        limit: ^limit,
        select: {
          e.site_id,
          fragment("countIf(? = 'pageview')", e.name),
          fragment("countIf(? != 'pageview')", e.name)
        }
      )
    )
  end

  def current_visitors(site) do
    Stats.current_visitors(site)
  end

  def current_visitors_12h(site) do
    Stats.current_visitors(site, Duration.new!(hour: -12))
  end
end
