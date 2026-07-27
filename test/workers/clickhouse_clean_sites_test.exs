defmodule Plausible.Workers.ClickhouseCleanSitesTest do
  use Plausible.DataCase
  import Plausible.Factory

  alias Plausible.Workers.ClickhouseCleanSites

  @tag :slow
  test "deletes data from events and sessions tables" do
    site = insert(:site)
    deleted_site = insert(:site)

    populate_stats(site, [
      build(:pageview),
      build(:pageview, timestamp: ~D[2026-01-01]),
      build(:imported_visitors),
      build(:imported_sources),
      build(:imported_pages),
      build(:imported_entry_pages),
      build(:imported_exit_pages),
      build(:imported_locations),
      build(:imported_devices),
      build(:imported_browsers),
      build(:imported_operating_systems),
      build(:imported_custom_events)
    ])

    populate_stats(deleted_site, [
      build(:pageview),
      build(:pageview, timestamp: ~D[2026-01-01]),
      build(:pageview, timestamp: ~D[2026-02-01]),
      build(:pageview, timestamp: ~D[2026-03-01]),
      build(:imported_visitors),
      build(:imported_sources),
      build(:imported_pages),
      build(:imported_entry_pages),
      build(:imported_exit_pages),
      build(:imported_locations),
      build(:imported_devices),
      build(:imported_browsers),
      build(:imported_operating_systems),
      build(:imported_custom_events)
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

    assert_count(deleted_site, "events_v2", 0)
    assert_count(deleted_site, "sessions_v2", 0)
    assert_count(deleted_site, "imported_visitors", 0)
    assert_count(deleted_site, "imported_sources", 0)
    assert_count(deleted_site, "imported_pages", 0)
    assert_count(deleted_site, "imported_entry_pages", 0)
    assert_count(deleted_site, "imported_exit_pages", 0)
    assert_count(deleted_site, "imported_locations", 0)
    assert_count(deleted_site, "imported_devices", 0)
    assert_count(deleted_site, "imported_browsers", 0)
    assert_count(deleted_site, "imported_operating_systems", 0)
    assert_count(deleted_site, "imported_custom_events", 0)
    assert_count(site, "events_v2", 2)
    assert_count(site, "sessions_v2", 2)
    assert_count(site, "imported_visitors", 1)
    assert_count(site, "imported_sources", 1)
    assert_count(site, "imported_pages", 1)
    assert_count(site, "imported_entry_pages", 1)
    assert_count(site, "imported_exit_pages", 1)
    assert_count(site, "imported_locations", 1)
    assert_count(site, "imported_devices", 1)
    assert_count(site, "imported_browsers", 1)
    assert_count(site, "imported_operating_systems", 1)
    assert_count(site, "imported_custom_events", 1)

    assert not Enum.member?(
             ClickhouseCleanSites.get_deleted_sites_with_clickhouse_data(),
             deleted_site.id
           )
  end

  @tag :slow
  test "cleans a deleted site that has only imported data and no native events" do
    kept_site = insert(:site)
    imported_only = insert(:site)

    # A live site with native events - must be left untouched.
    populate_stats(kept_site, [build(:pageview)])

    populate_stats(imported_only, [
      build(:imported_visitors),
      build(:imported_sources),
      build(:imported_custom_events)
    ])

    Repo.delete!(imported_only)

    assert Enum.member?(
             ClickhouseCleanSites.get_deleted_sites_with_clickhouse_data(),
             imported_only.id
           )

    ClickhouseCleanSites.perform(nil)

    assert_count(imported_only, "imported_visitors", 0)
    assert_count(imported_only, "imported_sources", 0)
    assert_count(imported_only, "imported_custom_events", 0)
    assert_count(kept_site, "events_v2", 1)
  end

  def assert_count(site, table, expected_count) do
    q = from(e in table, select: %{count: fragment("count()")}, where: e.site_id == ^site.id)
    assert await_clickhouse_count(q, expected_count)
  end
end
