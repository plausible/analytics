defmodule Plausible.Stats.QuerySpecialMetricsTest do
  use Plausible.DataCase
  alias Plausible.Stats
  alias Plausible.Stats.{ParsedQueryParams, QueryBuilder, QueryInclude}

  setup [:create_user, :create_site]

  describe "exit_rate" do
    test "in visit:exit_page breakdown without filters", %{site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 1, pathname: "/two", timestamp: ~N[2021-01-01 00:10:00]),
        build(:pageview, user_id: 3, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 3, pathname: "/never-exit", timestamp: ~N[2021-01-01 00:00:00]),
        build(:event,
          user_id: 3,
          name: "a",
          pathname: "/one",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview, user_id: 3, pathname: "/one", timestamp: ~N[2021-01-01 00:10:00])
      ])

      assert {:ok, query} =
               QueryBuilder.build(site, %ParsedQueryParams{
                 metrics: [:exit_rate],
                 input_date_range: :all,
                 dimensions: ["visit:exit_page"],
                 order_by: [{"visit:exit_page", :desc}]
               })

      assert %Stats.QueryResult{results: results} = Stats.query(site, query)

      assert results == [
               %{dimensions: ["/two"], metrics: [100]},
               %{dimensions: ["/one"], metrics: [33.3]}
             ]
    end

    test "in visit:exit_page breakdown filtered by visit:exit_page", %{site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 1, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 1, pathname: "/two", timestamp: ~N[2021-01-01 00:10:00])
      ])

      assert {:ok, query} =
               QueryBuilder.build(site, %ParsedQueryParams{
                 metrics: [:exit_rate],
                 input_date_range: :all,
                 dimensions: ["visit:exit_page"],
                 filters: [[:is, "visit:exit_page", ["/one"]]],
                 order_by: [{"visit:exit_page", :desc}]
               })

      assert %Stats.QueryResult{results: results} = Stats.query(site, query)

      assert results == [
               %{dimensions: ["/one"], metrics: [66.7]}
             ]
    end

    test "in visit:exit_page breakdown filtered by visit:exit_page and visit:entry_page", %{
      site: site
    } do
      populate_stats(site, [
        # Bounced sessions: Match both entry- and exit page filters
        build(:pageview, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        # Session 1: Matches both entry- and exit page filters
        build(:pageview, user_id: 1, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 1, pathname: "/two", timestamp: ~N[2021-01-01 00:10:00]),
        build(:pageview, user_id: 1, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        # Session 2: Does not match exit_page filter, BUT the pageview on /one still
        # gets counted towards total pageviews.
        build(:pageview, user_id: 2, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 2, pathname: "/two", timestamp: ~N[2021-01-01 00:10:00]),
        # Session 3: Does not match entry_page filter, should be ignored
        build(:pageview, user_id: 3, pathname: "/two", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 3, pathname: "/one", timestamp: ~N[2021-01-01 00:20:00])
      ])

      assert {:ok, query} =
               QueryBuilder.build(site, %ParsedQueryParams{
                 metrics: [:exit_rate],
                 input_date_range: :all,
                 dimensions: ["visit:exit_page"],
                 filters: [
                   [:is, "visit:exit_page", ["/one"]],
                   [:is, "visit:entry_page", ["/one"]]
                 ]
               })

      assert %Stats.QueryResult{results: results} = Stats.query(site, query)

      assert results == [
               %{dimensions: ["/one"], metrics: [60]}
             ]
    end

    test "in visit:exit_page breakdown filtered by visit:country", %{site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/one",
          country_code: "EE",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/one",
          country_code: "US",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 1,
          pathname: "/one",
          country_code: "EE",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 1,
          pathname: "/two",
          country_code: "EE",
          timestamp: ~N[2021-01-01 00:10:00]
        )
      ])

      assert {:ok, query} =
               QueryBuilder.build(site, %ParsedQueryParams{
                 metrics: [:exit_rate],
                 input_date_range: :all,
                 dimensions: ["visit:exit_page"],
                 filters: [
                   [:is, "visit:country", ["EE"]],
                   [:is, "visit:entry_page", ["/one"]]
                 ],
                 order_by: [{:exit_rate, :asc}]
               })

      assert %Stats.QueryResult{results: results} = Stats.query(site, query)

      assert results == [
               %{dimensions: ["/one"], metrics: [50]},
               %{dimensions: ["/two"], metrics: [100.0]}
             ]
    end

    test "sorting and pagination", %{site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 2, pathname: "/two", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 2, pathname: "/two", timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, user_id: 3, pathname: "/three", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 3, pathname: "/three", timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, user_id: 3, pathname: "/three", timestamp: ~N[2021-01-01 00:02:00]),
        build(:pageview, user_id: 4, pathname: "/four", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 4, pathname: "/four", timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, user_id: 4, pathname: "/four", timestamp: ~N[2021-01-01 00:02:00]),
        build(:pageview, user_id: 4, pathname: "/four", timestamp: ~N[2021-01-01 00:03:00])
      ])

      do_query = fn order_by, pagination ->
        {:ok, query} =
          QueryBuilder.build(site, %ParsedQueryParams{
            metrics: [:exit_rate],
            input_date_range: :all,
            dimensions: ["visit:exit_page"],
            order_by: order_by,
            pagination: pagination
          })

        %Stats.QueryResult{results: results} = Stats.query(site, query)
        results
      end

      all_results_asc = do_query.([{:exit_rate, :asc}], %{limit: 4, offset: 0})
      all_results_desc = do_query.([{:exit_rate, :desc}], %{limit: 4, offset: 0})

      assert all_results_asc == Enum.reverse(all_results_desc)

      assert do_query.([{:exit_rate, :desc}], %{limit: 2, offset: 0}) == [
               %{dimensions: ["/one"], metrics: [100]},
               %{dimensions: ["/two"], metrics: [50]}
             ]

      assert do_query.([{:exit_rate, :desc}], %{limit: 2, offset: 2}) == [
               %{dimensions: ["/three"], metrics: [33.3]},
               %{dimensions: ["/four"], metrics: [25]}
             ]

      assert do_query.([{:exit_rate, :asc}], %{limit: 3, offset: 1}) == [
               %{dimensions: ["/three"], metrics: [33.3]},
               %{dimensions: ["/two"], metrics: [50]},
               %{dimensions: ["/one"], metrics: [100]}
             ]
    end

    test "with comparisons", %{site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, pathname: "/one", timestamp: ~N[2021-01-09 00:00:00]),
        build(:pageview, user_id: 1, pathname: "/three", timestamp: ~N[2021-01-09 00:00:00]),
        build(:pageview, pathname: "/one", timestamp: ~N[2021-01-09 00:10:00]),
        build(:pageview, user_id: 2, pathname: "/one", timestamp: ~N[2021-01-10 00:00:00]),
        build(:pageview, user_id: 2, pathname: "/two", timestamp: ~N[2021-01-10 00:10:00]),
        build(:pageview, user_id: 3, pathname: "/one", timestamp: ~N[2021-01-10 00:00:00]),
        build(:pageview, user_id: 3, pathname: "/one", timestamp: ~N[2021-01-10 00:10:00])
      ])

      {:ok, query} =
        QueryBuilder.build(site, %ParsedQueryParams{
          metrics: [:exit_rate],
          input_date_range: {:date_range, ~D[2021-01-10], ~D[2021-01-10]},
          dimensions: ["visit:exit_page"],
          order_by: [{:exit_rate, :desc}],
          include: %QueryInclude{compare: :previous_period}
        })

      %Stats.QueryResult{results: results} = Stats.query(site, query)

      assert results == [
               %{
                 dimensions: ["/two"],
                 metrics: [100],
                 comparison: %{
                   change: [nil],
                   dimensions: ["/two"],
                   metrics: [nil]
                 }
               },
               %{
                 dimensions: ["/one"],
                 metrics: [33.3],
                 comparison: %{
                   change: [-16.7],
                   dimensions: ["/one"],
                   metrics: [50]
                 }
               }
             ]
    end

    test "with imported data", %{site: site} do
      site_import =
        insert(:site_import,
          site: site,
          start_date: ~D[2020-01-01],
          end_date: ~D[2020-12-31]
        )

      populate_stats(site, site_import.id, [
        build(:pageview, user_id: 1, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 1, pathname: "/two", timestamp: ~N[2021-01-01 00:10:00]),
        build(:pageview, user_id: 3, pathname: "/one", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 3, pathname: "/three", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 3, pathname: "/one", timestamp: ~N[2021-01-01 00:10:00]),
        build(:imported_pages, page: "/one", visits: 10, pageviews: 20, date: ~D[2020-01-01]),
        build(:imported_exit_pages, exit_page: "/one", exits: 2, date: ~D[2020-01-01])
      ])

      {:ok, query} =
        QueryBuilder.build(site, %ParsedQueryParams{
          metrics: [:exit_rate],
          input_date_range: :all,
          dimensions: ["visit:exit_page"],
          order_by: [{:exit_rate, :desc}],
          include: %QueryInclude{imports: true}
        })

      %Stats.QueryResult{results: results} = Stats.query(site, query)

      assert results == [
               %{dimensions: ["/two"], metrics: [100]},
               %{dimensions: ["/one"], metrics: [13]}
             ]
    end
  end
end
