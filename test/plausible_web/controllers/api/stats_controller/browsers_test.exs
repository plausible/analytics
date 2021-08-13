defmodule PlausibleWeb.Api.StatsController.BrowsersTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/browsers" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns top browsers by unique visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, browser: "Chrome"),
        build(:pageview, browser: "Chrome"),
        build(:pageview, browser: "Firefox")
      ])

      conn = get(conn, "/api/stats/#{site.domain}/browsers?period=day")

      assert json_response(conn, 200) == [
               %{"name" => "Chrome", "count" => 2, "percentage" => 67},
               %{"name" => "Firefox", "count" => 1, "percentage" => 33}
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
               %{"name" => "78.0", "count" => 2, "percentage" => 67},
               %{"name" => "77.0", "count" => 1, "percentage" => 33}
             ]
    end
  end
end
