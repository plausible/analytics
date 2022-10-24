defmodule Plausible.PurgeTest do
  use Plausible.DataCase

  setup do
    site = insert(:site, stats_start_date: ~D[2020-01-01])

    populate_stats(site, [
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

    {:ok, %{site: site}}
  end

  defp assert_count(query, expected) do
    assert eventually(
             fn ->
               count = Plausible.ClickhouseRepo.aggregate(query, :count)
               {count == expected, count}
             end,
             200,
             10
           )
  end

  test "delete_imported_stats!/1 deletes imported data", %{site: site} do
    Enum.each(Plausible.Imported.tables(), fn table ->
      query = from(imported in table, where: imported.site_id == ^site.id)
      assert_count(query, 1)
    end)

    assert :ok == Plausible.Purge.delete_imported_stats!(site)

    Enum.each(Plausible.Imported.tables(), fn table ->
      query = from(imported in table, where: imported.site_id == ^site.id)
      assert_count(query, 0)
    end)
  end

  test "delete_imported_stats!/1 resets stats_start_date", %{site: site} do
    assert :ok == Plausible.Purge.delete_imported_stats!(site)
    assert %Plausible.Site{stats_start_date: nil} = Plausible.Repo.reload(site)
  end

  test "delete_native_stats!/1 deletes native stats", %{site: site} do
    events_query = from(s in Plausible.ClickhouseEvent, where: s.domain == ^site.domain)
    assert_count(events_query, 1)

    sessions_query = from(s in Plausible.ClickhouseSession, where: s.domain == ^site.domain)
    assert_count(sessions_query, 1)

    assert :ok == Plausible.Purge.delete_native_stats!(site)

    assert_count(events_query, 0)
    assert_count(sessions_query, 0)
  end

  test "delete_native_stats!/1 resets stats_start_date", %{site: site} do
    assert :ok == Plausible.Purge.delete_native_stats!(site)
    assert %Plausible.Site{stats_start_date: nil} = Plausible.Repo.reload(site)
  end

  test "delete_site!/1 deletes the site and all stats", %{site: site} do
    events_query = from(s in Plausible.ClickhouseEvent, where: s.domain == ^site.domain)
    assert_count(events_query, 1)

    sessions_query = from(s in Plausible.ClickhouseSession, where: s.domain == ^site.domain)
    assert_count(sessions_query, 1)

    assert :ok == Plausible.Purge.delete_site!(site)
    assert nil == Plausible.Repo.reload(site)

    assert_count(events_query, 0)
    assert_count(sessions_query, 0)

    Enum.each(Plausible.Imported.tables(), fn table ->
      query = from(imported in table, where: imported.site_id == ^site.id)
      assert_count(query, 0)
    end)
  end
end
