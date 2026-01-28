defmodule PlausibleWeb.Api.StatsController.ScreenSizesTest do
  use PlausibleWeb.ConnCase

  setup [:create_user, :create_site, :create_api_key, :use_api_key]

  test "aggregates a single metric", %{conn: conn, site: site} do
    populate_stats(site, [
      build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:25:00]),
      build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
    ])

    conn =
      post(conn, "/stats/#{site.domain}/query", %{
        "metrics" => ["pageviews"],
        "date_range" => "all"
      })

    assert json_response(conn, 200)["results"] == [%{"metrics" => [3], "dimensions" => []}]
  end
end
