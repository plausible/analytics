defmodule PlausibleWeb.Api.ExternalStatsController.QueryImportedTest do
  use PlausibleWeb.ConnCase

  setup [:create_user, :create_site, :create_api_key, :use_api_key, :create_site_import]

  test "aggregated new_time_on_page metric", %{
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
        total_time_on_page: 9 * 20_000,
        total_time_on_page_visits: 9
      )
    ])

    conn =
      post(conn, "/api/v2/query-internal-test", %{
        "site_id" => site.domain,
        "metrics" => ["visitors", "new_time_on_page"],
        "date_range" => "all",
        "dimensions" => ["event:page"],
        "include" => %{"imports" => true},
        "order_by" => [["visitors", "desc"]]
      })

    assert_matches %{
                     "results" => [
                       %{"dimensions" => ["/blog"], "metrics" => [10, 30_000]}
                     ],
                     "meta" =>
                       ^strict_map(%{
                         "imports_included" => true
                       })
                   } = json_response(conn, 200)
  end
end
