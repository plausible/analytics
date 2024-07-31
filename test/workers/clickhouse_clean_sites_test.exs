defmodule Plausible.Workers.ClickhouseCleanSitesTest do
  use Plausible.DataCase
  use Plausible.TestUtils
  use Plausible
  import Plausible.Factory

  alias Plausible.Workers.ClickhouseCleanSites

  @tag :slow
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
    assert_count(site, "events_v2", 1)
    assert_count(site, "sessions_v2", 1)

    assert not Enum.member?(
             ClickhouseCleanSites.get_deleted_sites_with_clickhouse_data(),
             deleted_site.id
           )
  end

  def assert_count(site, table, expected_count) do
    q = from(e in table, select: %{count: fragment("count()")}, where: e.site_id == ^site.id)
    await_clickhouse_count(q, expected_count)
  end
end
