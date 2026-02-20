defmodule Plausible.Stats.Clickhouse do
  use Plausible
  use Plausible.Repo
  use Plausible.ClickhouseRepo
  use Plausible.Stats.SQL.Fragments

  import Ecto.Query, only: [from: 2]

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

  def current_visitors(site) do
    Stats.current_visitors(site)
  end

  def current_visitors_12h(site) do
    Stats.current_visitors(site, Duration.new!(hour: -12))
  end

  def has_pageviews?(site) do
    # This function is currently only used in installation verification
    # which is not accessible for consolidated views.
    true = Plausible.Sites.regular?(site)

    ClickhouseRepo.exists?(
      from(e in "events_v2",
        where:
          e.site_id == ^site.id and
            e.name == "pageview" and
            e.timestamp >=
              ^site.native_stats_start_at
      )
    )
  end
end
