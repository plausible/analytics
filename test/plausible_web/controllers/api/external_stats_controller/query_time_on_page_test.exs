defmodule PlausibleWeb.Api.ExternalStatsController.QueryImportedTest do
  use PlausibleWeb.ConnCase

  setup [:create_user, :create_site, :create_api_key, :use_api_key, :create_site_import]

  test "aggregated new_time_on_page metric based on engagement data", %{
    conn: conn,
    site: site
  } do
    populate_stats(site, [
      build(:pageview, user_id: 12, pathname: "/blog", timestamp: ~N[2021-01-01 00:00:00]),
      build(:engagement,
        user_id: 12,
        pathname: "/blog",
        timestamp: ~N[2021-01-01 00:10:00],
        engagement_time: 120_000
      ),
      build(:engagement,
        user_id: 12,
        pathname: "/blog",
        timestamp: ~N[2021-01-01 00:11:00],
        engagement_time: 20_000
      ),
      build(:pageview, user_id: 13, pathname: "/blog", timestamp: ~N[2021-01-01 00:10:00]),
      build(:engagement,
        user_id: 13,
        pathname: "/blog",
        timestamp: ~N[2021-01-01 00:10:00],
        engagement_time: 60_000
      )
    ])

    conn =
      post(conn, "/api/v2/query-internal-test", %{
        "site_id" => site.domain,
        "metrics" => ["new_time_on_page"],
        "date_range" => "all",
        "dimensions" => ["event:page"],
        "include" => %{"imports" => true}
      })

    assert json_response(conn, 200)["results"] == [
             %{"dimensions" => ["/blog"], "metrics" => [100]}
           ]
  end

  test "aggregated new_time_on_page metric with imported data", %{
    conn: conn,
    site: site,
    site_import: site_import
  } do
    populate_stats(site, site_import.id, [
      build(:pageview, user_id: 12, pathname: "/blog", timestamp: ~N[2021-01-01 00:00:00]),
      build(:engagement,
        user_id: 12,
        pathname: "/blog",
        timestamp: ~N[2021-01-01 00:10:00],
        engagement_time: 120_000
      ),
      build(:imported_pages,
        page: "/blog",
        date: ~D[2021-01-01],
        visitors: 9,
        total_time_on_page: 9 * 20,
        total_time_on_page_visits: 9
      )
    ])

    conn =
      post(conn, "/api/v2/query-internal-test", %{
        "site_id" => site.domain,
        "metrics" => ["new_time_on_page"],
        "date_range" => "all",
        "dimensions" => ["event:page"],
        "include" => %{"imports" => true}
      })

    assert_matches %{
                     "results" => [
                       %{"dimensions" => ["/blog"], "metrics" => [30]}
                     ],
                     "meta" =>
                       ^strict_map(%{
                         "imports_included" => true
                       })
                   } = json_response(conn, 200)
  end

  test "new_time_on_page time series", %{conn: conn, site: site, site_import: site_import} do
    populate_stats(site, site_import.id, [
      build(:pageview, user_id: 12, pathname: "/", timestamp: ~N[2021-01-01 00:00:00]),
      build(:engagement,
        user_id: 12,
        pathname: "/",
        timestamp: ~N[2021-01-01 00:00:00],
        engagement_time: 100_000
      ),
      build(:pageview, user_id: 12, pathname: "/", timestamp: ~N[2021-01-02 00:00:00]),
      build(:engagement,
        user_id: 12,
        pathname: "/",
        timestamp: ~N[2021-01-02 00:00:00],
        engagement_time: 100_000
      ),
      build(:pageview, user_id: 13, pathname: "/", timestamp: ~N[2021-01-02 00:00:00]),
      build(:engagement,
        user_id: 13,
        pathname: "/",
        timestamp: ~N[2021-01-02 00:00:00],
        engagement_time: 300_000
      ),
      build(:pageview, user_id: 12, pathname: "/", timestamp: ~N[2021-01-03 00:00:00]),
      build(:engagement,
        user_id: 12,
        pathname: "/",
        timestamp: ~N[2021-01-03 00:00:00],
        engagement_time: 100_000
      ),
      build(:pageview, user_id: 12, pathname: "/", timestamp: ~N[2021-01-04 00:00:00]),
      build(:engagement,
        user_id: 12,
        pathname: "/",
        timestamp: ~N[2021-01-04 00:00:00],
        engagement_time: 100_000
      ),
      build(:imported_pages,
        page: "/blog",
        date: ~D[2021-01-01],
        visitors: 9,
        total_time_on_page: 9 * 20,
        total_time_on_page_visits: 9
      )
    ])

    conn =
      post(conn, "/api/v2/query-internal-test", %{
        "site_id" => site.domain,
        "metrics" => ["new_time_on_page"],
        "date_range" => ["2021-01-01", "2021-01-04"],
        "dimensions" => ["time:day", "event:page"],
        "include" => %{"imports" => true}
      })

    assert json_response(conn, 200)["results"] == [
             %{"dimensions" => ["2021-01-01", "/"], "metrics" => [100]},
             %{"dimensions" => ["2021-01-01", "/blog"], "metrics" => [20]},
             %{"dimensions" => ["2021-01-02", "/"], "metrics" => [200]},
             %{"dimensions" => ["2021-01-03", "/"], "metrics" => [100]},
             %{"dimensions" => ["2021-01-04", "/"], "metrics" => [100]}
           ]
  end

  describe "legacy time_on_page metric" do
    test "aggregated", %{conn: conn, site: site, site_import: site_import} do
      populate_stats(site, site_import.id, [
        build(:pageview, pathname: "/A", user_id: 111, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, pathname: "/B", user_id: 111, timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, pathname: "/A", user_id: 999, timestamp: ~N[2021-01-02 00:00:00]),
        build(:pageview, pathname: "/B", user_id: 999, timestamp: ~N[2021-01-02 00:01:30]),
        # These are ignored for time_on_page metric
        build(:imported_pages, page: "/A", time_on_page: 40, date: ~D[2021-01-01]),
        build(:imported_pages, page: "/B", time_on_page: 499, date: ~D[2021-01-01])
      ])

      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "time_on_page"],
          "date_range" => "all",
          "filters" => [["is", "event:page", ["/A"]]],
          "include" => %{"imports" => true}
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => [], "metrics" => [3, 75]}
             ]
    end

    test "breakdown", %{conn: conn, site: site, site_import: site_import} do
      populate_stats(site, site_import.id, [
        build(:pageview, pathname: "/A", user_id: 111, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, pathname: "/B", user_id: 111, timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, pathname: "/A", user_id: 999, timestamp: ~N[2021-01-02 00:00:00]),
        build(:pageview, pathname: "/B", user_id: 999, timestamp: ~N[2021-01-02 00:01:30]),
        build(:pageview, pathname: "/C", user_id: 999, timestamp: ~N[2021-01-02 00:02:00]),
        # :TODO: include imported data to show it's not used
        build(:imported_pages, page: "/A", time_on_page: 40, date: ~D[2021-01-01]),
        build(:imported_pages, page: "/B", time_on_page: 499, date: ~D[2021-01-01])
      ])

      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "time_on_page"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "include" => %{"imports" => true}
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["/A"], "metrics" => [3, 63.333333333333336]},
               %{"dimensions" => ["/B"], "metrics" => [3, 264.5]},
               %{"dimensions" => ["/C"], "metrics" => [1, nil]}
             ]
    end
  end
end
