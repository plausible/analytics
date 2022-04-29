defmodule PlausibleWeb.Api.StatsController.BrowsersTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/browsers" do
    setup [:create_user, :log_in, :create_new_site, :add_imported_data]

    test "returns top browsers by unique visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, browser: "Chrome"),
        build(:pageview, browser: "Chrome"),
        build(:pageview, browser: "Firefox")
      ])

      conn = get(conn, "/api/stats/#{site.domain}/browsers?period=day")

      assert json_response(conn, 200) == [
               %{"name" => "Chrome", "visitors" => 2, "percentage" => 67},
               %{"name" => "Firefox", "visitors" => 1, "percentage" => 33}
             ]
    end

    test "calculates conversion_rate when filtering for goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, browser: "Chrome"),
        build(:pageview, user_id: 2, browser: "Chrome"),
        build(:event, user_id: 1, name: "Signup")
      ])

      filters = Jason.encode!(%{"goal" => "Signup"})

      conn = get(conn, "/api/stats/#{site.domain}/browsers?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Chrome",
                 "total_visitors" => 2,
                 "visitors" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end

    test "returns top browsers including imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, browser: "Chrome"),
        build(:imported_browsers, browser: "Chrome"),
        build(:imported_browsers, browser: "Firefox")
      ])

      conn = get(conn, "/api/stats/#{site.domain}/browsers?period=day")

      assert json_response(conn, 200) == [
               %{"name" => "Chrome", "visitors" => 1, "percentage" => 100}
             ]

      conn = get(conn, "/api/stats/#{site.domain}/browsers?period=day&with_imported=true")

      assert json_response(conn, 200) == [
               %{"name" => "Chrome", "visitors" => 2, "percentage" => 67},
               %{"name" => "Firefox", "visitors" => 1, "percentage" => 33}
             ]
    end
  end

  describe "GET /api/stats/:domain/browser-versions" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns top browser versions by unique visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, browser: "Chrome", browser_version: "78.0"),
        build(:pageview, browser: "Chrome", browser_version: "78.0"),
        build(:pageview, browser: "Chrome", browser_version: "77.0"),
        build(:pageview, browser: "Firefox", browser_version: "88.0")
      ])

      filters = Jason.encode!(%{browser: "Chrome"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/browser-versions?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{"name" => "78.0", "visitors" => 2, "percentage" => 67},
               %{"name" => "77.0", "visitors" => 1, "percentage" => 33}
             ]
    end
  end
end
