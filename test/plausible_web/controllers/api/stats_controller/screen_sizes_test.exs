defmodule PlausibleWeb.Api.StatsController.ScreenSizesTest do
  use PlausibleWeb.ConnCase

  describe "GET /api/stats/:domain/browsers" do
    setup [:create_user, :log_in, :create_new_site, :add_imported_data]

    test "returns screen sizes by new visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, session_screen_size: "Desktop"),
        build(:pageview, session_screen_size: "Desktop"),
        build(:pageview, session_screen_size: "Laptop")
      ])

      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day")

      assert json_response(conn, 200) == [
               %{"name" => "Desktop", "visitors" => 2, "percentage" => 66.7},
               %{"name" => "Laptop", "visitors" => 1, "percentage" => 33.3}
             ]
    end

    test "returns screen sizes for user making multiple sessions", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 1,
          session_screen_size: "Desktop",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 1,
          session_screen_size: "Laptop",
          timestamp: ~N[2021-01-01 05:00:00]
        )
      ])

      conn =
        get(conn, "/api/stats/#{site.domain}/screen-sizes", %{
          "period" => "day",
          "date" => "2021-01-01"
        })

      assert json_response(conn, 200) == [
               %{"name" => "Desktop", "visitors" => 1, "percentage" => 100},
               %{"name" => "Laptop", "visitors" => 1, "percentage" => 100}
             ]
    end

    test "returns (not set) when appropriate", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          session_screen_size: ""
        ),
        build(:pageview,
          session_screen_size: "Desktop"
        )
      ])

      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day")

      assert json_response(conn, 200) == [
               %{"name" => "(not set)", "visitors" => 1, "percentage" => 50},
               %{"name" => "Desktop", "visitors" => 1, "percentage" => 50}
             ]

      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day")

      filters = Jason.encode!(%{screen: "(not set)"})
      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{"name" => "(not set)", "visitors" => 1, "percentage" => 100}
             ]
    end

    test "returns screen sizes with :is filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          session_screen_size: "Desktop"
        ),
        build(:pageview,
          user_id: 123,
          session_screen_size: "Desktop",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          session_screen_size: "Mobile",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview,
          session_screen_size: "Tablet"
        )
      ])

      filters = Jason.encode!(%{props: %{"author" => "John Doe"}})
      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{"name" => "Desktop", "visitors" => 1, "percentage" => 100}
             ]
    end

    test "returns screen sizes with :is_not filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          session_screen_size: "Desktop",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          user_id: 123,
          session_screen_size: "Desktop",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          session_screen_size: "Mobile",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview,
          session_screen_size: "Tablet"
        )
      ])

      filters = Jason.encode!(%{props: %{"author" => "!John Doe"}})
      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{"name" => "Mobile", "visitors" => 1, "percentage" => 50},
               %{"name" => "Tablet", "visitors" => 1, "percentage" => 50}
             ]
    end

    test "returns screen sizes by new visitors with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, session_screen_size: "Desktop"),
        build(:pageview, session_screen_size: "Desktop"),
        build(:pageview, session_screen_size: "Laptop")
      ])

      populate_stats(site, [
        build(:imported_devices, device: "Mobile"),
        build(:imported_devices, device: "Laptop"),
        build(:imported_visitors, visitors: 2)
      ])

      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day")

      assert json_response(conn, 200) == [
               %{"name" => "Desktop", "visitors" => 2, "percentage" => 66.7},
               %{"name" => "Laptop", "visitors" => 1, "percentage" => 33.3}
             ]

      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day&with_imported=true")

      assert json_response(conn, 200) == [
               %{"name" => "Desktop", "visitors" => 2, "percentage" => 40},
               %{"name" => "Laptop", "visitors" => 2, "percentage" => 40},
               %{"name" => "Mobile", "visitors" => 1, "percentage" => 20}
             ]
    end

    test "returns screen sizes for user making multiple sessions by no of visitors with imported data",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 1,
          session_screen_size: "Desktop",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 1,
          session_screen_size: "Laptop",
          timestamp: ~N[2021-01-01 05:00:00]
        )
      ])

      populate_stats(site, [
        build(:imported_devices, device: "Desktop", date: ~D[2021-01-01]),
        build(:imported_devices, device: "Laptop", date: ~D[2021-01-01]),
        build(:imported_visitors, visitors: 2, date: ~D[2021-01-01])
      ])

      conn =
        get(conn, "/api/stats/#{site.domain}/screen-sizes", %{
          "period" => "day",
          "date" => "2021-01-01",
          "with_imported" => "true"
        })

      assert json_response(conn, 200) == [
               %{"name" => "Desktop", "visitors" => 2, "percentage" => 66.7},
               %{"name" => "Laptop", "visitors" => 2, "percentage" => 66.7}
             ]
    end

    test "calculates conversion_rate when filtering for goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, session_screen_size: "Desktop"),
        build(:pageview, user_id: 2, session_screen_size: "Desktop"),
        build(:event, user_id: 1, name: "Signup")
      ])

      filters = Jason.encode!(%{"goal" => "Signup"})

      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Desktop",
                 "total_visitors" => 2,
                 "visitors" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end

    test "returns screen sizes with not_member filter type", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, session_referrer_source: "Google", session_screen_size: "Desktop"),
        build(:pageview, session_referrer_source: "Bad source", session_screen_size: "Desktop"),
        build(:pageview, session_referrer_source: "Google", session_screen_size: "Desktop"),
        build(:pageview, session_referrer_source: "Twitter", session_screen_size: "Mobile"),
        build(:pageview,
          session_referrer_source: "Second bad source",
          session_screen_size: "Mobile"
        )
      ])

      filters = Jason.encode!(%{"source" => "!Bad source|Second bad source"})

      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{"name" => "Desktop", "visitors" => 2, "percentage" => 66.7},
               %{"name" => "Mobile", "visitors" => 1, "percentage" => 33.3}
             ]
    end
  end
end
