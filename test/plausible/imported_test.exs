defmodule Plausible.ImportedTest do
  use Plausible.DataCase
  use Plausible

  alias Plausible.Imported

  describe "list_all_imports/1" do
    test "returns empty when there are no imports" do
      site = insert(:site)

      assert Imported.list_all_imports(site) == []
    end

    test "returns imports in various states" do
      site = insert(:site)

      _rogue_import = insert(:site_import)

      import1 = insert(:site_import, site: site, status: :pending)
      import2 = insert(:site_import, site: site, status: :importing)
      import3 = insert(:site_import, site: site, status: :completed)
      import4 = insert(:site_import, site: site, status: :failed)

      assert [%{id: id1}, %{id: id2}, %{id: id3}, %{id: id4}] = Imported.list_all_imports(site)

      ids = [id1, id2, id3, id4]

      assert import1.id in ids
      assert import2.id in ids
      assert import3.id in ids
      assert import4.id in ids
    end

    test "returns one legacy import when present with respective site import entry" do
      site = insert(:site)
      {:ok, opts} = add_imported_data(%{site: site})
      site = Map.new(opts).site
      site_import = insert(:site_import, site: site, legacy: true)
      site_import_id = site_import.id

      assert [%{id: ^site_import_id}] = Imported.list_all_imports(site)
    end

    test "returns legacy import without respective site import entry" do
      site = insert(:site)
      {:ok, opts} = add_imported_data(%{site: site})
      site = Map.new(opts).site
      imported_start_date = site.imported_data.start_date
      imported_end_date = site.imported_data.end_date

      assert [
               %{
                 id: 0,
                 source: :universal_analytics,
                 start_date: ^imported_start_date,
                 end_date: ^imported_end_date,
                 status: :completed
               }
             ] = Imported.list_all_imports(site)
    end
  end

  describe "check_dates/3" do
    test "crops dates from both ends when overlapping with existing import and native stats" do
      site = insert(:site)

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2023-10-25 15:58:00])
      ])

      start_date = ~D[2016-04-03]
      end_date = ~D[2021-05-12]

      _existing_import =
        insert(:site_import,
          site: site,
          start_date: start_date,
          end_date: end_date,
          status: :completed
        )

      assert {:ok, ~D[2021-05-12], ~D[2023-10-25]} =
               Imported.check_dates(site, ~D[2021-04-11], ~D[2024-01-12])
    end

    test "picks longest conitnuous range when containing existing import" do
      site = insert(:site)

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2023-10-25 15:58:00])
      ])

      start_date = ~D[2019-04-03]
      end_date = ~D[2021-05-12]

      _existing_import =
        insert(:site_import,
          site: site,
          start_date: start_date,
          end_date: end_date,
          status: :completed
        )

      assert {:ok, ~D[2021-05-12], ~D[2023-10-25]} =
               Imported.check_dates(site, ~D[2019-03-21], ~D[2024-01-12])
    end

    test "does not alter the dates when there are no imports and no native stats" do
      site = insert(:site)

      assert {:ok, ~D[2021-05-12], ~D[2024-01-12]} =
               Imported.check_dates(site, ~D[2021-05-12], ~D[2024-01-12])
    end

    test "ignores input date range difference smaller than 2 days" do
      site = insert(:site)

      assert {:error, :no_time_window} =
               Imported.check_dates(site, ~D[2024-01-12], ~D[2024-01-12])

      assert {:error, :no_time_window} =
               Imported.check_dates(site, ~D[2024-01-12], ~D[2024-01-13])

      assert {:ok, ~D[2024-01-12], ~D[2024-01-14]} =
               Imported.check_dates(site, ~D[2024-01-12], ~D[2024-01-14])
    end

    test "ignores imports with date range difference smaller than 2 days" do
      site = insert(:site)

      start_date = ~D[2024-01-12]
      end_date = ~D[2024-01-13]

      _existing_import =
        insert(:site_import,
          site: site,
          start_date: start_date,
          end_date: end_date,
          status: :completed
        )

      assert {:ok, ~D[2021-04-22], ~D[2024-03-14]} =
               Imported.check_dates(site, ~D[2021-04-22], ~D[2024-03-14])
    end

    test "returns no time window when input range starts after native stats start date" do
      site = insert(:site)

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2023-10-25 15:58:00])
      ])

      assert {:error, :no_time_window} =
               Imported.check_dates(site, ~D[2023-10-28], ~D[2024-01-13])
    end

    test "returns no time window when input range starts less than 2 days before native stats start date" do
      site = insert(:site)

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2023-10-25 15:58:00])
      ])

      assert {:error, :no_time_window} =
               Imported.check_dates(site, ~D[2023-10-24], ~D[2024-01-13])
    end

    test "crops time range at native stats start date when effective range is 2 days or longer" do
      site = insert(:site)

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2023-10-25 15:58:00])
      ])

      assert {:ok, ~D[2023-10-23], ~D[2023-10-25]} =
               Imported.check_dates(site, ~D[2023-10-23], ~D[2024-01-13])
    end

    test "returns no data error when start date missing" do
      site = insert(:site)

      assert {:error, :no_data} = Imported.check_dates(site, nil, nil)
    end

    test "returns no time window error when date range overlaps with existing import and stats completely" do
      site = insert(:site)

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2023-10-25 15:58:00])
      ])

      start_date = ~D[2016-04-03]
      end_date = ~D[2023-10-25]

      _existing_import =
        insert(:site_import,
          site: site,
          start_date: start_date,
          end_date: end_date,
          status: :completed
        )

      assert {:error, :no_time_window} =
               Imported.check_dates(site, ~D[2021-04-11], ~D[2024-01-12])
    end
  end
end
