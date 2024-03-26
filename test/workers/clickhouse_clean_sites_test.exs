defmodule Plausible.Workers.ClickhouseCleanSitesTest do
  use Plausible.DataCase
  use Plausible.TestUtils
  use Plausible
  import Plausible.Factory

  alias Plausible.Workers.ClickhouseCleanSites

  test "deletes data from events and sessions tables" do
    site = insert(:site)
    deleted_site = insert(:site)

    populate_stats(site, [
      build(:pageview)
    ])

    populate_stats(deleted_site, [
      build(:pageview),
      build(:pageview),
      build(:imported_visitors),
      build(:imported_sources),
      build(:imported_pages),
      build(:imported_entry_pages),
      build(:imported_exit_pages),
      build(:imported_locations),
      build(:imported_devices),
      build(:imported_browsers),
      build(:imported_operating_systems)
    ])

    Repo.delete!(deleted_site)

    assert Enum.member?(
             ClickhouseCleanSites.get_deleted_sites_with_clickhouse_data(),
             deleted_site.id
           )

    assert not Enum.member?(
             ClickhouseCleanSites.get_deleted_sites_with_clickhouse_data(),
             site.id
           )

    ClickhouseCleanSites.perform(nil)

    assert not Enum.member?(
             ClickhouseCleanSites.get_deleted_sites_with_clickhouse_data(),
             deleted_site.id
           )

    assert get_count("events_v2") == 1
    assert get_count("sessions_v2") == 1
    assert get_count("imported_visitors") == 0
    assert get_count("imported_sources") == 0
    assert get_count("imported_pages") == 0
    assert get_count("imported_entry_pages") == 0
    assert get_count("imported_exit_pages") == 0
    assert get_count("imported_locations") == 0
    assert get_count("imported_devices") == 0
    assert get_count("imported_browsers") == 0
    assert get_count("imported_operating_systems") == 0
  end

  def get_count(table) do
    %{count: count} =
      from(e in table, select: %{count: fragment("count()")}) |> Plausible.ClickhouseRepo.one()

    count
  end
end
