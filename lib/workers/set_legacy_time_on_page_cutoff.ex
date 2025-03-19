defmodule Plausible.Workers.SetLegacyTimeOnPageCutoff do
  @moduledoc """
  Sets sites `legacy_time_on_page_cutoff` depending on whether they have
  sent us engagement data in the past.
  """

  use Plausible.Repo
  use Plausible.ClickhouseRepo
  use Oban.Worker, queue: :legacy_time_on_page_cutoff

  import Ecto.Query

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    {small_sites, large_sites} =
      sites_with_engagement_data()
      |> filter_sites_needing_update()

    to_update = small_sites ++ large_sites
    today = Date.utc_today()

    if length(to_update) > 0 do
      Logger.info(
        "Setting legacy_time_on_page_cutoff for #{length(to_update)} sites (#{length(small_sites)} small, #{length(large_sites)} large)"
      )

      {count, _} =
        Repo.update_all(
          from(s in Plausible.Site,
            where: s.id in ^to_update,
            where: is_nil(s.legacy_time_on_page_cutoff)
          ),
          set: [legacy_time_on_page_cutoff: today]
        )

      Logger.info("Successfully set legacy_time_on_page_cutoff=#{today} for #{count} sites")
    else
      Logger.debug("No sites legacy_time_on_page_cutoff needs updating")
    end

    :ok
  end

  defp sites_with_engagement_data() do
    site_info_q =
      from(
        e in "events_v2",
        where: e.timestamp > fragment("toStartOfHour(now() - toIntervalHour(48))"),
        where: e.timestamp < fragment("toStartOfHour(now() - toIntervalHour(24))"),
        group_by: e.site_id,
        select: %{
          site_id: e.site_id,
          hours_with_engagement:
            fragment(
              "uniqIf(toStartOfHour(timestamp), name = 'engagement' AND engagement_time > 0)"
            ),
          is_small_site: fragment("count() < 2000")
        }
      )

    q =
      from(
        s in subquery(site_info_q),
        select: %{
          small_sites:
            fragment("groupArrayIf(site_id, (is_small_site and hours_with_engagement > 0))"),
          large_sites:
            fragment("groupArrayIf(site_id, (not is_small_site and hours_with_engagement = 24))")
        }
      )

    result = ClickhouseRepo.one(q)

    {MapSet.new(result.small_sites), MapSet.new(result.large_sites)}
  end

  defp filter_sites_needing_update({small_sites, large_sites}) do
    needing_update =
      from(s in Plausible.Site,
        where: is_nil(s.legacy_time_on_page_cutoff),
        select: s.id
      )
      |> Repo.all()
      |> MapSet.new()

    {
      small_sites |> MapSet.intersection(needing_update) |> MapSet.to_list(),
      large_sites |> MapSet.intersection(needing_update) |> MapSet.to_list()
    }
  end
end
