defmodule Plausible.PurgeTest do
  use Plausible.DataCase, async: true
  use Plausible.Teams.Test

  setup do
    user = new_user()
    site = new_site(owner: user, stats_start_date: ~D[2005-01-01])

    import_params = %{
      source: :universal_analytics,
      start_date: ~D[2005-01-01],
      end_date: Timex.today()
    }

    [site_import1, site_import2] =
      Enum.map(1..2, fn _ ->
        site
        |> Plausible.Imported.SiteImport.create_changeset(
          user,
          import_params
        )
        |> Plausible.Repo.insert!()
        |> Plausible.Imported.SiteImport.complete_changeset()
        |> Plausible.Repo.update!()
      end)

    populate_stats(site, site_import1.id, [
      build(:pageview),
      build(:imported_visitors),
      build(:imported_sources),
      build(:imported_pages),
      build(:imported_entry_pages),
      build(:imported_exit_pages),
      build(:imported_custom_events),
      build(:imported_locations),
      build(:imported_devices),
      build(:imported_browsers),
      build(:imported_operating_systems)
    ])

    populate_stats(site, site_import2.id, [
      build(:pageview),
      build(:imported_visitors),
      build(:imported_sources),
      build(:imported_pages),
      build(:imported_entry_pages),
      build(:imported_exit_pages),
      build(:imported_custom_events),
      build(:imported_locations),
      build(:imported_devices),
      build(:imported_browsers),
      build(:imported_operating_systems)
    ])

    {:ok, %{site: site, site_import1: site_import1, site_import2: site_import2}}
  end

  test "delete_imported_stats!/1 deletes imported data", %{site: site} do
    Enum.each(Plausible.Imported.tables(), fn table ->
      query = from(imported in table, where: imported.site_id == ^site.id)
      assert await_clickhouse_count(query, 2)
    end)

    assert :ok == Plausible.Purge.delete_imported_stats!(site)

    Enum.each(Plausible.Imported.tables(), fn table ->
      query = from(imported in table, where: imported.site_id == ^site.id)
      assert await_clickhouse_count(query, 0)
    end)
  end

  test "delete_imported_stats!/1 deletes imported data only for a particular site import", %{
    site_import1: site_import1,
    site_import2: site_import2
  } do
    Enum.each(Plausible.Imported.tables(), fn table ->
      query = from(imported in table, where: imported.import_id == ^site_import1.id)
      assert await_clickhouse_count(query, 1)

      query = from(imported in table, where: imported.import_id == ^site_import2.id)
      assert await_clickhouse_count(query, 1)
    end)

    assert :ok == Plausible.Purge.delete_imported_stats!(site_import1)

    Enum.each(Plausible.Imported.tables(), fn table ->
      query = from(imported in table, where: imported.import_id == ^site_import1.id)
      assert await_clickhouse_count(query, 0)

      query = from(imported in table, where: imported.import_id == ^site_import2.id)
      assert await_clickhouse_count(query, 1)
    end)
  end

  test "delete_imported_stats!/2 deletes legacy imported data only when instructed", %{
    site: site,
    site_import1: site_import1,
    site_import2: site_import2
  } do
    populate_stats(site, [
      build(:pageview),
      build(:imported_visitors),
      build(:imported_sources),
      build(:imported_pages),
      build(:imported_entry_pages),
      build(:imported_exit_pages),
      build(:imported_custom_events),
      build(:imported_locations),
      build(:imported_devices),
      build(:imported_browsers),
      build(:imported_operating_systems)
    ])

    Enum.each(Plausible.Imported.tables(), fn table ->
      query =
        from(imported in table,
          where: imported.site_id == ^site.id and imported.import_id == ^site_import1.id
        )

      assert await_clickhouse_count(query, 1)

      query =
        from(imported in table,
          where: imported.site_id == ^site.id and imported.import_id == ^site_import2.id
        )

      assert await_clickhouse_count(query, 1)

      query =
        from(imported in table, where: imported.site_id == ^site.id and imported.import_id == 0)

      assert await_clickhouse_count(query, 1)
    end)

    assert :ok == Plausible.Purge.delete_imported_stats!(site, 0)

    Enum.each(Plausible.Imported.tables(), fn table ->
      query =
        from(imported in table,
          where: imported.site_id == ^site.id and imported.import_id == ^site_import1.id
        )

      assert await_clickhouse_count(query, 1)

      query =
        from(imported in table,
          where: imported.site_id == ^site.id and imported.import_id == ^site_import2.id
        )

      assert await_clickhouse_count(query, 1)

      query =
        from(imported in table, where: imported.site_id == ^site.id and imported.import_id == 0)

      assert await_clickhouse_count(query, 0)
    end)
  end

  test "delete_imported_stats!/1 resets stats_start_date", %{site: site} do
    assert :ok == Plausible.Purge.delete_imported_stats!(site)
    assert %Plausible.Site{stats_start_date: nil} = Plausible.Repo.reload(site)
  end

  test "delete_native_stats!/1 moves the native_stats_start_at pointer", %{site: site} do
    assert :ok == Plausible.Purge.delete_native_stats!(site)

    assert %Plausible.Site{native_stats_start_at: native_stats_start_at} =
             Plausible.Repo.reload(site)

    assert NaiveDateTime.compare(native_stats_start_at, site.native_stats_start_at) == :gt
  end

  test "delete_native_stats!/1 resets stats_start_date", %{site: site} do
    assert :ok == Plausible.Purge.delete_native_stats!(site)
    assert %Plausible.Site{stats_start_date: nil} = Plausible.Repo.reload(site)
  end
end
