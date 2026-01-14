defmodule Plausible.Stats.QueryImportedTest do
  use Plausible.DataCase
  alias Plausible.Stats
  alias Plausible.Stats.{ParsedQueryParams, QueryBuilder, QueryInclude}

  @unsupported_query_warning Plausible.Stats.QueryResult.imports_warnings().unsupported_query
  @no_imported_scroll_depth_warning Plausible.Stats.QueryResult.no_imported_scroll_depth_warning()

  setup [:create_user, :create_site]

  describe "behavioral filters" do
    setup :create_site_import

    test "imports are skipped when has_done filter is used", %{
      site: site,
      site_import: site_import
    } do
      populate_stats(site, site_import.id, [
        build(:event, name: "pageview", user_id: 1, timestamp: ~N[2021-01-01 00:00:00]),
        build(:event, name: "pageview", user_id: 2, timestamp: ~N[2021-01-01 00:00:00]),
        build(:event, name: "Conversion", user_id: 3, timestamp: ~N[2021-01-01 00:00:00]),
        build(:imported_pages,
          page: "/blog",
          pageviews: 5,
          visitors: 3,
          date: ~D[2023-01-01]
        )
      ])

      assert {:ok, query} =
               QueryBuilder.build(site, %ParsedQueryParams{
                 metrics: [:visitors],
                 input_date_range: :all,
                 filters: [[:has_done, [:is, "event:name", ["pageview"]]]],
                 include: %QueryInclude{imports: true}
               })

      assert %Stats.QueryResult{results: results, meta: meta} = Stats.query(site, query)

      assert results == [%{dimensions: [], metrics: [2]}]
      refute meta[:imports_included]

      assert meta[:imports_warning] == @unsupported_query_warning
    end

    test "imports are skipped when has_not_done filter is used", %{
      site: site,
      site_import: site_import
    } do
      populate_stats(site, site_import.id, [
        build(:event, name: "pageview", user_id: 1, timestamp: ~N[2021-01-01 00:00:00]),
        build(:event, name: "pageview", user_id: 2, timestamp: ~N[2021-01-01 00:00:00]),
        build(:event, name: "Conversion", user_id: 3, timestamp: ~N[2021-01-01 00:00:00]),
        build(:imported_pages,
          page: "/blog",
          pageviews: 5,
          visitors: 3,
          date: ~D[2023-01-01]
        )
      ])

      assert {:ok, query} =
               QueryBuilder.build(site, %ParsedQueryParams{
                 metrics: [:visitors],
                 input_date_range: :all,
                 dimensions: ["event:goal"],
                 filters: [[:has_not_done, [:is, "event:name", ["pageview"]]]],
                 include: %QueryInclude{imports: true}
               })

      assert %Stats.QueryResult{results: results, meta: meta} = Stats.query(site, query)

      assert results == []
      refute meta[:imports_included]

      assert meta[:imports_warning] == @unsupported_query_warning
    end
  end

  describe "scroll depth metric warnings" do
    test "returns warning when import without scroll depth in comparison range", %{
      site: site
    } do
      site_import =
        insert(:site_import, site: site, start_date: ~D[2021-02-01], end_date: ~D[2021-02-28])

      populate_stats(site, site_import.id, [
        build(:pageview, user_id: 123, pathname: "/", timestamp: ~N[2021-02-01 00:00:00]),
        build(:engagement,
          user_id: 123,
          pathname: "/",
          timestamp: ~N[2021-02-01 00:01:00],
          scroll_depth: 70
        ),
        build(:imported_pages, page: "/", date: ~D[2021-02-01]),
        build(:imported_pages, page: "/", date: ~D[2021-02-28])
      ])

      assert {:ok, query} =
               QueryBuilder.build(site, %ParsedQueryParams{
                 metrics: [:visitors, :scroll_depth],
                 input_date_range: {:date_range, ~D[2022-01-01], ~D[2022-12-31]},
                 filters: [[:is, "event:page", ["/"]]],
                 include: %QueryInclude{imports: true, compare: :previous_period}
               })

      assert %Stats.QueryResult{results: results, meta: meta} = Stats.query(site, query)

      assert results == [
               %{
                 dimensions: [],
                 metrics: [0, nil],
                 comparison: %{
                   change: [-100, nil],
                   dimensions: [],
                   metrics: [3, 70]
                 }
               }
             ]

      assert meta[:imports_included] == true

      assert meta[:metric_warnings] == %{
               scroll_depth: @no_imported_scroll_depth_warning
             }
    end
  end
end
