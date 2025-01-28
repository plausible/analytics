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
  end

  describe "earliest_import_start_date/1" do
    test "returns nil if no site_imports exist" do
      site = insert(:site)

      assert is_nil(Imported.earliest_import_start_date(site))
    end

    test "returns nil when only incomplete or failed imports are present" do
      site = insert(:site)

      _import1 = insert(:site_import, site: site, status: :pending)
      _import2 = insert(:site_import, site: site, status: :importing)
      _import3 = insert(:site_import, site: site, status: :failed)
      _rogue_import = insert(:site_import, site: build(:site), status: :completed)

      assert is_nil(Imported.earliest_import_start_date(site))
    end

    test "returns start and end dates considering all imports" do
      site = insert(:site)

      _import1 =
        insert(:site_import,
          site: site,
          start_date: ~D[2020-04-02],
          end_date: ~D[2022-06-22],
          status: :completed,
          legacy: true
        )

      _import2 =
        insert(:site_import,
          site: site,
          start_date: ~D[2022-06-22],
          end_date: ~D[2024-01-08],
          status: :completed
        )

      assert Imported.earliest_import_start_date(site) == ~D[2020-04-02]
    end
  end

  describe "latest_import_end_date/1" do
    test "returns nil if no site_imports exist" do
      site = insert(:site)

      assert is_nil(Imported.latest_import_end_date(site))
    end

    test "returns nil when only incomplete or failed imports are present" do
      site = insert(:site)

      _import1 = insert(:site_import, site: site, status: :pending)
      _import2 = insert(:site_import, site: site, status: :importing)
      _import3 = insert(:site_import, site: site, status: :failed)
      _rogue_import = insert(:site_import, site: build(:site), status: :completed)

      assert is_nil(Imported.latest_import_end_date(site))
    end

    test "returns start and end dates considering all imports" do
      site = insert(:site)

      _import1 =
        insert(:site_import,
          site: site,
          start_date: ~D[2020-04-02],
          end_date: ~D[2022-06-22],
          status: :completed,
          legacy: true
        )

      _import2 =
        insert(:site_import,
          site: site,
          start_date: ~D[2022-06-22],
          end_date: ~D[2024-01-08],
          status: :completed
        )

      assert Imported.latest_import_end_date(site) == ~D[2024-01-08]
    end
  end

  describe "clamp_dates/3" do
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
               Imported.clamp_dates(site, ~D[2021-04-11], ~D[2024-01-12])
    end

    test "picks longest continuous range when containing existing import" do
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
               Imported.clamp_dates(site, ~D[2019-03-21], ~D[2024-01-12])
    end

    test "does not depend on the order of insertion of site imports (regression fix)" do
      site = insert(:site)

      _existing_import1 =
        insert(:site_import,
          site: site,
          start_date: ~D[2020-10-14],
          end_date: ~D[2024-04-01],
          status: :completed
        )

      _existing_import2 =
        insert(:site_import,
          site: site,
          start_date: ~D[2012-01-18],
          end_date: ~D[2018-03-09],
          status: :completed
        )

      assert {:ok, ~D[2018-03-09], ~D[2020-10-14]} =
               Imported.clamp_dates(site, ~D[2012-01-18], ~D[2018-03-09])
    end

    test "does not alter the dates when there are no imports and no native stats" do
      site = insert(:site)

      assert {:ok, ~D[2021-05-12], ~D[2024-01-12]} =
               Imported.clamp_dates(site, ~D[2021-05-12], ~D[2024-01-12])
    end

    test "ignores input date range difference smaller than 2 days" do
      site = insert(:site)

      assert {:error, :no_time_window} =
               Imported.clamp_dates(site, ~D[2024-01-12], ~D[2024-01-12])

      assert {:error, :no_time_window} =
               Imported.clamp_dates(site, ~D[2024-01-12], ~D[2024-01-13])

      assert {:ok, ~D[2024-01-12], ~D[2024-01-14]} =
               Imported.clamp_dates(site, ~D[2024-01-12], ~D[2024-01-14])
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
               Imported.clamp_dates(site, ~D[2021-04-22], ~D[2024-03-14])
    end

    test "returns no time window when input range starts after native stats start date" do
      site = insert(:site)

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2023-10-25 15:58:00])
      ])

      assert {:error, :no_time_window} =
               Imported.clamp_dates(site, ~D[2023-10-28], ~D[2024-01-13])
    end

    test "returns no time window when input range starts less than 2 days before native stats start date" do
      site = insert(:site)

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2023-10-25 15:58:00])
      ])

      assert {:error, :no_time_window} =
               Imported.clamp_dates(site, ~D[2023-10-24], ~D[2024-01-13])
    end

    test "crops time range at native stats start date when effective range is 2 days or longer" do
      site = insert(:site)

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2023-10-25 15:58:00])
      ])

      assert {:ok, ~D[2023-10-23], ~D[2023-10-25]} =
               Imported.clamp_dates(site, ~D[2023-10-23], ~D[2024-01-13])
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
               Imported.clamp_dates(site, ~D[2021-04-11], ~D[2024-01-12])
    end
  end
end
