defmodule Plausible.Stats.ClickhouseTest do
  use Plausible.DataCase, async: true

  alias Plausible.Stats.Clickhouse

  describe "imported_pageview_counts/1" do
    test "gets pageview counts for each of sites' imports" do
      site = new_site()

      import1 = insert(:site_import, site: site)
      import2 = insert(:site_import, site: site)

      # legacy import
      populate_stats(site, [
        build(:imported_visitors, pageviews: 5),
        build(:imported_visitors, pageviews: 6)
      ])

      populate_stats(site, import1.id, [
        build(:imported_visitors, pageviews: 6),
        build(:imported_visitors, pageviews: 8)
      ])

      populate_stats(site, import2.id, [
        build(:imported_visitors, pageviews: 7),
        build(:imported_visitors, pageviews: 13)
      ])

      pageview_counts = Clickhouse.imported_pageview_counts(site)

      assert map_size(pageview_counts) == 3
      assert pageview_counts[0] == 11
      assert pageview_counts[import1.id] == 14
      assert pageview_counts[import2.id] == 20
    end
  end

  describe "partition_ids/2" do
    test "returns a single partition id when both dates fall in the same month" do
      assert Clickhouse.partition_ids(~D[2024-01-01], ~D[2024-01-31]) == ["202401"]
      assert Clickhouse.partition_ids(~D[2024-01-15], ~D[2024-01-15]) == ["202401"]
    end

    test "returns one partition id per month spanned, inclusive of both ends" do
      assert Clickhouse.partition_ids(~D[2024-01-15], ~D[2024-03-10]) == [
               "202401",
               "202402",
               "202403"
             ]
    end

    test "year boundary" do
      assert Clickhouse.partition_ids(~D[2023-11-05], ~D[2024-02-20]) == [
               "202311",
               "202312",
               "202401",
               "202402"
             ]
    end

    test "returns an empty list when from_date is after to_date" do
      assert Clickhouse.partition_ids(~D[2024-03-01], ~D[2024-01-01]) == []
    end

    test "month boundary" do
      assert Clickhouse.partition_ids(~D[2024-01-31], ~D[2024-02-01]) == ["202401", "202402"]
    end
  end
end
