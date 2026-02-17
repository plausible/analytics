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
end
