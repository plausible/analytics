defmodule Plausible.DataMigration.SiteImportsTest do
  use Plausible.DataCase, async: true

  import ExUnit.CaptureIO

  alias Plausible.DataMigration.SiteImports
  alias Plausible.Imported
  alias Plausible.Repo

  describe "run/1" do
    test "runs for empty dataset" do
      dry_run_output =
        capture_io(fn ->
          assert :ok = SiteImports.run()
        end)

      assert dry_run_output =~ "Backfilling legacy site import across 0 sites"
      assert dry_run_output =~ "DRY RUN: true"

      real_run_output =
        capture_io(fn ->
          assert :ok = SiteImports.run(dry_run?: false)
        end)

      assert real_run_output =~ "Backfilling legacy site import across 0 sites"
      assert real_run_output =~ "DRY RUN: false"
    end

    test "adds site import entry when it's missing and adjusts end date" do
      site =
        insert(:site)
        |> start_import(~D[2021-01-02], ~D[2021-01-08], "Google Analytics", "ok")
        |> Repo.update!()

      populate_stats(site, 0, [
        build(:imported_visitors, date: ~D[2021-01-07])
      ])

      assert capture_io(fn ->
               assert :ok = SiteImports.run(dry_run?: false)
             end) =~ "Backfilling legacy site import across 1 sites"

      site = Repo.reload!(site)

      assert [%{id: id, legacy: true} = site_import] = Imported.list_all_imports(site)
      assert id > 0
      assert site_import.start_date == site.imported_data.start_date
      assert site_import.end_date == ~D[2021-01-07]
      assert site.imported_data.end_date == ~D[2021-01-07]
      assert site_import.source == :universal_analytics
    end

    test "runs in dry mode without making any persistent changes" do
      site =
        insert(:site)
        |> start_import(~D[2021-01-02], ~D[2021-01-08], "Google Analytics", "ok")
        |> Repo.update!()

      populate_stats(site, 0, [
        build(:imported_visitors, date: ~D[2021-01-07])
      ])

      output =
        capture_io(fn ->
          assert :ok = SiteImports.run()
        end)

      assert output =~ "Backfilling legacy site import across 1 sites"
      assert output =~ "Adjusting end dates of 1 site imports"

      site = Repo.reload!(site)

      assert [] = Imported.list_all_imports(site)
      assert site.imported_data.end_date == ~D[2021-01-08]
    end

    test "does not set end date to latter than the current one" do
      site =
        insert(:site)
        |> start_import(~D[2021-01-02], ~D[2021-01-08], "Google Analytics", "ok")
        |> Repo.update!()

      populate_stats(site, 0, [
        build(:imported_visitors, date: ~D[2021-01-10])
      ])

      assert capture_io(fn ->
               assert :ok = SiteImports.run(dry_run?: false)
             end) =~ "Backfilling legacy site import across 1 sites"

      site = Repo.reload!(site)

      assert [%{id: id, legacy: true} = site_import] = Imported.list_all_imports(site)
      assert id > 0
      assert site_import.start_date == site.imported_data.start_date
      assert site_import.end_date == ~D[2021-01-08]
      assert site.imported_data.end_date == ~D[2021-01-08]
      assert site_import.source == :universal_analytics
    end

    test "removes site import when there are no stats" do
      site =
        insert(:site)
        |> start_import(~D[2021-01-02], ~D[2020-02-02], "Google Analytics", "ok")
        |> Repo.update!()

      assert capture_io(fn ->
               assert :ok = SiteImports.run(dry_run?: false)
             end) =~ "Backfilling legacy site import across 1 sites"

      site = Repo.reload!(site)
      assert [] = Imported.list_all_imports(site)
      assert site.imported_data == nil
    end

    test "leaves site and imports unchanged if everything fits" do
      site =
        insert(:site)
        |> start_import(~D[2021-01-02], ~D[2021-01-08], "Google Analytics", "ok")
        |> Repo.update!()

      existing_import =
        new_site_import(
          site: site,
          start_date: ~D[2021-01-02],
          end_date: ~D[2021-01-08],
          status: :completed,
          legacy: true
        )

      populate_stats(site, existing_import.id, [
        build(:imported_visitors, date: ~D[2021-01-08])
      ])

      assert capture_io(fn ->
               assert :ok = SiteImports.run(dry_run?: false)
             end) =~ "Backfilling legacy site import across 0 sites"

      site = Repo.reload!(site)

      assert [%{id: id, legacy: true} = site_import] = Imported.list_all_imports(site)
      assert id == existing_import.id
      assert site_import.start_date == site.imported_data.start_date
      assert site_import.end_date == ~D[2021-01-08]
      assert site_import.source == :universal_analytics
    end

    test "only considers sites with completed site imports or 'ok' imported data" do
      site1 =
        insert(:site)
        |> start_import(~D[2021-01-02], ~D[2021-01-08], "Google Analytics", "error")
        |> Repo.update!()

      existing_import1 =
        new_site_import(
          site: site1,
          start_date: ~D[2021-01-02],
          end_date: ~D[2021-01-08],
          status: :completed,
          legacy: false
        )

      site2 =
        insert(:site)
        |> start_import(~D[2021-01-02], ~D[2021-01-08], "Google Analytics", "ok")
        |> Repo.update!()

      existing_import2 =
        new_site_import(
          site: site2,
          start_date: ~D[2021-01-02],
          end_date: ~D[2021-01-08],
          status: :failed,
          legacy: false
        )

      site3 =
        insert(:site)
        |> start_import(~D[2021-01-02], ~D[2021-01-08], "Google Analytics", "error")
        |> Repo.update!()

      site4 =
        insert(:site)
        |> start_import(~D[2021-01-02], ~D[2021-01-08], "Google Analytics", "error")
        |> Repo.update!()

      _existing_import3 =
        new_site_import(
          site: site4,
          start_date: ~D[2021-01-02],
          end_date: ~D[2021-01-08],
          status: :failed,
          legacy: true
        )

      output =
        capture_io(fn ->
          assert :ok = SiteImports.run(dry_run?: false)
        end)

      assert output =~ "Backfilling legacy site import across 1 sites"
      assert output =~ "Adjusting end dates of 2 site imports"
      assert output =~ "(site ID #{site1.id})"
      assert output =~ "site import #{existing_import1.id} "
      assert output =~ "(site ID #{site2.id})"
      refute output =~ "site import #{existing_import2.id} "
      refute output =~ "(site ID #{site3.id})"
      refute output =~ "(site ID #{site4.id})"
    end
  end

  describe "imported_stats_end_date/1" do
    test "returns nil when there are no stats" do
      site_import = new_site_import()

      assert SiteImports.imported_stats_end_date(site_import.site_id, [site_import.id]) == nil
    end

    test "returns date when there are stats recorded in one imported table" do
      site_import = new_site_import()

      populate_stats(site_import.site, site_import.id, [
        build(:imported_visitors, date: ~D[2021-01-01])
      ])

      assert SiteImports.imported_stats_end_date(site_import.site_id, [site_import.id]) ==
               ~D[2021-01-01]
    end

    test "returns max date across all imported tables" do
      site_import = new_site_import()

      populate_stats(site_import.site, site_import.id, [
        build(:imported_visitors, date: ~D[2021-01-01]),
        build(:imported_visitors, date: ~D[2021-01-07]),
        build(:imported_sources, date: ~D[2021-01-01]),
        build(:imported_sources, date: ~D[2021-01-08]),
        build(:imported_entry_pages, date: ~D[2021-01-02]),
        build(:imported_entry_pages, date: ~D[2021-02-11]),
        build(:imported_exit_pages, date: ~D[2021-01-01]),
        build(:imported_exit_pages, date: ~D[2021-01-08]),
        build(:imported_locations, date: ~D[2021-01-01]),
        build(:imported_locations, date: ~D[2021-01-08]),
        build(:imported_devices, date: ~D[2021-01-01]),
        build(:imported_devices, date: ~D[2021-01-08]),
        build(:imported_browsers, date: ~D[2021-01-01]),
        build(:imported_browsers, date: ~D[2021-01-08]),
        build(:imported_operating_systems, date: ~D[2021-01-01]),
        build(:imported_operating_systems, date: ~D[2021-01-08])
      ])

      assert SiteImports.imported_stats_end_date(site_import.site_id, [site_import.id]) ==
               ~D[2021-02-11]
    end

    test "considers all imported tables (existing April 2024)" do
      date = ~D[2021-01-11]

      all_tables = SiteImports.imported_tables_april_2024()

      for {table, idx} <- Enum.with_index(all_tables) do
        site_import = new_site_import()
        end_date = Date.add(date, idx)

        populate_stats(site_import.site, site_import.id, [
          build(String.to_atom(table), date: date),
          build(String.to_atom(table), date: end_date)
        ])

        assert SiteImports.imported_stats_end_date(site_import.site_id, [site_import.id]) ==
                 end_date
      end
    end
  end

  defp start_import(site, start_date, end_date, imported_source, status) do
    change(site,
      imported_data: %{
        start_date: start_date,
        end_date: end_date,
        source: imported_source,
        status: status
      }
    )
  end
end
