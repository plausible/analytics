defmodule PlausibleWeb.Api.ExternalStatsController.TimeseriesTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  setup [:create_user, :create_site]

  test "shows last 6 months of visitors", %{conn: conn, site: site} do
    populate_stats([
      build(:pageview, domain: site.domain, timestamp: ~N[2020-12-31 00:00:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
    ])

    conn = get(conn, "/api/stats/timeseries", %{"site_id" => site.domain, "period" => "6mo"})

    assert json_response(conn, 200) == [
             %{"date" => "2020-08-01", "value" => 0},
             %{"date" => "2020-09-01", "value" => 0},
             %{"date" => "2020-10-01", "value" => 0},
             %{"date" => "2020-11-01", "value" => 0},
             %{"date" => "2020-12-01", "value" => 1},
             %{"date" => "2021-01-01", "value" => 2}
           ]
  end

  test "shows last 12 months of visitors", %{conn: conn, site: site} do
    populate_stats([
      build(:pageview, domain: site.domain, timestamp: ~N[2020-02-01 00:00:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2020-12-31 00:00:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00])
    ])

    conn = get(conn, "/api/stats/timeseries", %{"site_id" => site.domain, "period" => "12mo"})

    assert json_response(conn, 200) == [
             %{"date" => "2020-02-01", "value" => 1},
             %{"date" => "2020-03-01", "value" => 0},
             %{"date" => "2020-04-01", "value" => 0},
             %{"date" => "2020-05-01", "value" => 0},
             %{"date" => "2020-06-01", "value" => 0},
             %{"date" => "2020-07-01", "value" => 0},
             %{"date" => "2020-08-01", "value" => 0},
             %{"date" => "2020-09-01", "value" => 0},
             %{"date" => "2020-10-01", "value" => 0},
             %{"date" => "2020-11-01", "value" => 0},
             %{"date" => "2020-12-01", "value" => 1},
             %{"date" => "2021-01-01", "value" => 2}
           ]
  end

  test "shows a custom range", %{conn: conn, site: site} do
    populate_stats([
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-01 00:00:00]),
      build(:pageview, domain: site.domain, timestamp: ~N[2021-01-02 00:00:00])
    ])

    conn =
      get(conn, "/api/stats/timeseries", %{
        "site_id" => site.domain,
        "period" => "custom",
        "from" => "2021-01-01",
        "to" => "2021-01-02"
      })

    assert json_response(conn, 200) == [
             %{"date" => "2021-01-01", "value" => 2},
             %{"date" => "2021-01-02", "value" => 1}
           ]
  end
end
