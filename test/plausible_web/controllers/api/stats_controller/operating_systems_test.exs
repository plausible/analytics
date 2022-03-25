defmodule PlausibleWeb.Api.StatsController.OperatingSystemsTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/operating_systems" do
    setup [:create_user, :log_in, :create_new_site, :add_imported_data]

    test "returns operating systems by unique visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, operating_system: "Mac"),
        build(:pageview, operating_system: "Mac"),
        build(:pageview, operating_system: "Android")
      ])

      conn = get(conn, "/api/stats/#{site.domain}/operating-systems?period=day")

      assert json_response(conn, 200) == [
               %{"name" => "Mac", "visitors" => 2, "percentage" => 67},
               %{"name" => "Android", "visitors" => 1, "percentage" => 33}
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
               %{
                 "name" => "Mac",
                 "total_visitors" => 2,
                 "visitors" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end

    test "returns operating systems by unique visitors with imported data", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, operating_system: "Mac"),
        build(:pageview, operating_system: "Mac"),
        build(:pageview, operating_system: "Android"),
        build(:imported_operating_systems, operating_system: "Mac"),
        build(:imported_operating_systems, operating_system: "Android")
      ])

      conn = get(conn, "/api/stats/#{site.domain}/operating-systems?period=day")

      assert json_response(conn, 200) == [
               %{"name" => "Mac", "visitors" => 2, "percentage" => 67},
               %{"name" => "Android", "visitors" => 1, "percentage" => 33}
             ]

      conn =
        get(conn, "/api/stats/#{site.domain}/operating-systems?period=day&with_imported=true")

      assert json_response(conn, 200) == [
               %{"name" => "Mac", "visitors" => 3, "percentage" => 60},
               %{"name" => "Android", "visitors" => 2, "percentage" => 40}
             ]
    end

    test "imported data is ignored when filtering for goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, operating_system: "Mac"),
        build(:pageview, user_id: 2, operating_system: "Mac"),
        build(:imported_operating_systems, operating_system: "Mac"),
        build(:event, user_id: 1, name: "Signup")
      ])

      filters = Jason.encode!(%{"goal" => "Signup"})

      conn =
        get(conn, "/api/stats/#{site.domain}/operating-systems?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Mac",
                 "total_visitors" => 2,
                 "visitors" => 1,
                 "conversion_rate" => 50.0
               }
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
               %{"name" => "10.16", "visitors" => 2, "percentage" => 67},
               %{"name" => "10.15", "visitors" => 1, "percentage" => 33}
             ]
    end
  end
end
