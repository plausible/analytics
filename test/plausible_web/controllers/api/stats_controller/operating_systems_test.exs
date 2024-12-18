defmodule PlausibleWeb.Api.StatsController.OperatingSystemsTest do
  use PlausibleWeb.ConnCase

  describe "GET /api/stats/:domain/operating-systems" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "returns operating systems by unique visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, operating_system: "Mac"),
        build(:pageview, operating_system: "Mac"),
        build(:pageview, operating_system: "Android")
      ])

      conn = get(conn, "/api/stats/#{site.domain}/operating-systems?period=day")

      assert json_response(conn, 200)["results"] == [
               %{"name" => "Mac", "visitors" => 2, "percentage" => 66.7},
               %{"name" => "Android", "visitors" => 1, "percentage" => 33.3}
             ]
    end

    test "returns (not set) when appropriate", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          operating_system: ""
        ),
        build(:pageview,
          operating_system: "Linux"
        )
      ])

      conn1 = get(conn, "/api/stats/#{site.domain}/operating-systems?period=day")

      assert json_response(conn1, 200)["results"] == [
               %{"name" => "(not set)", "visitors" => 1, "percentage" => 50},
               %{"name" => "Linux", "visitors" => 1, "percentage" => 50}
             ]

      filters = Jason.encode!([[:is, "visit:os", ["(not set)"]]])

      conn2 =
        get(conn, "/api/stats/#{site.domain}/operating-systems?period=day&filters=#{filters}")

      assert json_response(conn2, 200)["results"] == [
               %{"name" => "(not set)", "visitors" => 1, "percentage" => 100}
             ]
    end

    test "select empty imported_operating_systems as (not set), merging with the native (not set)",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 123),
        build(:imported_operating_systems, visitors: 1),
        build(:imported_visitors, visitors: 1)
      ])

      conn =
        get(conn, "/api/stats/#{site.domain}/operating-systems?period=day&with_imported=true")

      assert json_response(conn, 200)["results"] == [
               %{"name" => "(not set)", "visitors" => 2, "percentage" => 100.0}
             ]
    end

    test "calculates conversion_rate when filtering for goal", %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Signup")

      populate_stats(site, [
        build(:pageview, user_id: 1, operating_system: "Mac"),
        build(:pageview, user_id: 2, operating_system: "Mac"),
        build(:event, user_id: 1, name: "Signup")
      ])

      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      conn =
        get(conn, "/api/stats/#{site.domain}/operating-systems?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "Mac",
                 "total_visitors" => 2,
                 "visitors" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end

    test "returns operating systems with :is filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          operating_system: "Mac"
        ),
        build(:pageview,
          user_id: 123,
          operating_system: "Mac",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          operating_system: "Windows",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview,
          operating_system: "Android"
        )
      ])

      filters = Jason.encode!([[:is, "event:props:author", ["John Doe"]]])

      conn =
        get(conn, "/api/stats/#{site.domain}/operating-systems?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{"name" => "Mac", "visitors" => 1, "percentage" => 100}
             ]
    end

    test "returns screen sizes with :is_not filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          operating_system: "Windows",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          user_id: 123,
          operating_system: "Windows",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          operating_system: "Mac",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview,
          operating_system: "Android"
        )
      ])

      filters = Jason.encode!([["is_not", "event:props:author", ["John Doe"]]])

      conn =
        get(conn, "/api/stats/#{site.domain}/operating-systems?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{"name" => "Android", "visitors" => 1, "percentage" => 50},
               %{"name" => "Mac", "visitors" => 1, "percentage" => 50}
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
        build(:imported_operating_systems, operating_system: "Android"),
        build(:imported_visitors, visitors: 2)
      ])

      conn1 = get(conn, "/api/stats/#{site.domain}/operating-systems?period=day")

      assert json_response(conn1, 200)["results"] == [
               %{"name" => "Mac", "visitors" => 2, "percentage" => 66.7},
               %{"name" => "Android", "visitors" => 1, "percentage" => 33.3}
             ]

      conn2 =
        get(conn, "/api/stats/#{site.domain}/operating-systems?period=day&with_imported=true")

      assert json_response(conn2, 200)["results"] == [
               %{"name" => "Mac", "visitors" => 3, "percentage" => 60},
               %{"name" => "Android", "visitors" => 2, "percentage" => 40}
             ]
    end

    test "imported data is ignored when filtering for goal", %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Signup")

      populate_stats(site, [
        build(:pageview, user_id: 1, operating_system: "Mac"),
        build(:pageview, user_id: 2, operating_system: "Mac"),
        build(:imported_operating_systems, operating_system: "Mac"),
        build(:event, user_id: 1, name: "Signup")
      ])

      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      conn =
        get(conn, "/api/stats/#{site.domain}/operating-systems?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
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
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "returns top OS versions by unique visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          operating_system: "Mac",
          operating_system_version: "10.15"
        ),
        build(:pageview,
          operating_system: "Mac",
          operating_system_version: "10.16"
        ),
        build(:pageview,
          operating_system: "Mac",
          operating_system_version: "10.16"
        ),
        build(:pageview,
          operating_system: "Android",
          operating_system_version: "4"
        )
      ])

      filters = Jason.encode!([[:is, "visit:os", ["Mac"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/operating-system-versions?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "Mac 10.16",
                 "visitors" => 2,
                 "percentage" => 66.7,
                 "os" => "Mac",
                 "version" => "10.16"
               },
               %{
                 "name" => "Mac 10.15",
                 "visitors" => 1,
                 "percentage" => 33.3,
                 "os" => "Mac",
                 "version" => "10.15"
               }
             ]
    end

    test "returns only version under the name key (+ additional metrics) when 'detailed' is true in params",
         %{
           conn: conn,
           site: site
         } do
      populate_stats(site, [
        build(:pageview, operating_system: "Mac", operating_system_version: "14")
      ])

      filters = Jason.encode!([[:is, "visit:os", ["Mac"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/operating-system-versions?filters=#{filters}&detailed=true"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "14",
                 "os" => "Mac",
                 "visitors" => 1,
                 "bounce_rate" => 100,
                 "visit_duration" => 0,
                 "percentage" => 100.0
               }
             ]
    end

    test "with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          operating_system: "Mac",
          operating_system_version: "11",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          operating_system: "Mac",
          operating_system_version: "12",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:imported_operating_systems,
          date: ~D[2021-01-01],
          operating_system: "Mac",
          operating_system_version: "11",
          visitors: 5
        ),
        build(:imported_operating_systems,
          date: ~D[2021-01-01],
          operating_system: "Windows",
          operating_system_version: "11",
          visitors: 3
        ),
        build(:imported_operating_systems, date: ~D[2021-01-01], visitors: 10),
        build(:imported_visitors, date: ~D[2021-01-01], visitors: 18)
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/operating-system-versions?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "os" => "(not set)",
                 "name" => "(not set)",
                 "version" => "(not set)",
                 "visitors" => 10,
                 "percentage" => 50.0
               },
               %{
                 "os" => "Mac",
                 "name" => "Mac 11",
                 "version" => "11",
                 "visitors" => 6,
                 "percentage" => 30.0
               },
               %{
                 "os" => "Windows",
                 "name" => "Windows 11",
                 "version" => "11",
                 "visitors" => 3,
                 "percentage" => 15.0
               },
               %{
                 "os" => "Mac",
                 "name" => "Mac 12",
                 "version" => "12",
                 "visitors" => 1,
                 "percentage" => 5.0
               }
             ]
    end
  end
end
