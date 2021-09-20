defmodule PlausibleWeb.Api.StatsController.OperatingSystemsTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/operating_systems" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns operating systems by unique visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, operating_system: "Mac"),
        build(:pageview, operating_system: "Mac"),
        build(:pageview, operating_system: "Android")
      ])

      conn = get(conn, "/api/stats/#{site.domain}/operating-systems?period=day")

      assert json_response(conn, 200) == [
               %{"name" => "Mac", "count" => 2, "percentage" => 67},
               %{"name" => "Android", "count" => 1, "percentage" => 33}
             ]
    end

    test "calculates conversion_rate when filtering for goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, operating_system: "Mac"),
        build(:pageview, user_id: 2, operating_system: "Mac"),
        build(:event, user_id: 1, name: "Signup")
      ])

      filters = Jason.encode!(%{"goal" => "Signup"})

      conn =
        get(conn, "/api/stats/#{site.domain}/operating-systems?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{"name" => "Mac", "count" => 1, "percentage" => 100, "conversion_rate" => 50.0}
             ]
    end
  end

  describe "GET /api/stats/:domain/operating-system-versions" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns top OS versions by unique visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, operating_system: "Mac", operating_system_version: "10.15"),
        build(:pageview, operating_system: "Mac", operating_system_version: "10.16"),
        build(:pageview, operating_system: "Mac", operating_system_version: "10.16"),
        build(:pageview, operating_system: "Android", operating_system_version: "4")
      ])

      filters = Jason.encode!(%{os: "Mac"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/operating-system-versions?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{"name" => "10.16", "count" => 2, "percentage" => 67},
               %{"name" => "10.15", "count" => 1, "percentage" => 33}
             ]
    end
  end
end
