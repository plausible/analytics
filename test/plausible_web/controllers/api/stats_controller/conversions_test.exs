defmodule PlausibleWeb.Api.StatsController.ConversionsTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/conversions" do
    setup [:create_user, :log_in, :create_site]

    test "returns mixed conversions in ordered by count", %{conn: conn, site: site} do
      insert(:goal, %{domain: site.domain, page_path: "/register"})
      insert(:goal, %{domain: site.domain, event_name: "Signup"})

      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&date=2019-01-01")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Signup",
                 "count" => 3,
                 "total_count" => 3,
                 "prop_names" => ["variant"],
                 "conversion_rate" => 42.9
               },
               %{
                 "name" => "Visit /register",
                 "count" => 2,
                 "total_count" => 2,
                 "prop_names" => nil,
                 "conversion_rate" => 28.6
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/conversions - with goal filter" do
    setup [:create_user, :log_in, :create_site]

    test "returns only the conversion tha is filtered for", %{conn: conn, site: site} do
      insert(:goal, %{domain: site.domain, page_path: "/register"})
      insert(:goal, %{domain: site.domain, event_name: "Signup"})

      filters = Jason.encode!(%{goal: "Signup"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&date=2019-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Signup",
                 "count" => 3,
                 "total_count" => 3,
                 "prop_names" => ["variant"],
                 "conversion_rate" => 42.9
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/property/:key" do
    setup [:create_user, :log_in, :create_site]

    test "returns metadata breakdown for goal", %{conn: conn, site: site} do
      insert(:goal, %{domain: site.domain, event_name: "Signup"})
      filters = Jason.encode!(%{goal: "Signup"})
      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/#{prop_key}?period=day&date=2019-01-01&filters=#{
            filters
          }"
        )

      assert json_response(conn, 200) == [
               %{"count" => 2, "name" => "B", "total_count" => 2, "conversion_rate" => 28.6},
               %{"count" => 1, "name" => "A", "total_count" => 1, "conversion_rate" => 14.3}
             ]
    end
  end

  describe "GET /api/stats/:domain/conversions - with glob goals" do
    setup [:create_user, :log_in, :create_site]

    test "returns correct and sorted glob goal counts", %{conn: conn, site: site} do
      insert(:goal, %{domain: site.domain, page_path: "/register"})
      insert(:goal, %{domain: site.domain, page_path: "/reg*"})
      insert(:goal, %{domain: site.domain, page_path: "/*/register"})
      insert(:goal, %{domain: site.domain, page_path: "/billing**/success"})
      insert(:goal, %{domain: site.domain, page_path: "/billing*/success"})
      insert(:goal, %{domain: site.domain, page_path: "/signup"})
      insert(:goal, %{domain: site.domain, page_path: "/signup/*"})
      insert(:goal, %{domain: site.domain, page_path: "/signup/**"})
      insert(:goal, %{domain: site.domain, page_path: "/*"})
      insert(:goal, %{domain: site.domain, page_path: "/**"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&date=2019-07-01"
        )

      assert json_response(conn, 200) == [
               %{
                 "conversion_rate" => 100.0,
                 "count" => 8,
                 "name" => "Visit /**",
                 "total_count" => 8,
                 "prop_names" => nil
               },
               %{
                 "conversion_rate" => 37.5,
                 "count" => 3,
                 "name" => "Visit /*",
                 "total_count" => 3,
                 "prop_names" => nil
               },
               %{
                 "conversion_rate" => 37.5,
                 "count" => 3,
                 "name" => "Visit /signup/**",
                 "total_count" => 3,
                 "prop_names" => nil
               },
               %{
                 "conversion_rate" => 25.0,
                 "count" => 2,
                 "name" => "Visit /billing**/success",
                 "total_count" => 2,
                 "prop_names" => nil
               },
               %{
                 "conversion_rate" => 25.0,
                 "count" => 2,
                 "name" => "Visit /reg*",
                 "total_count" => 2,
                 "prop_names" => nil
               },
               %{
                 "conversion_rate" => 12.5,
                 "count" => 1,
                 "name" => "Visit /billing*/success",
                 "total_count" => 1,
                 "prop_names" => nil
               },
               %{
                 "conversion_rate" => 12.5,
                 "count" => 1,
                 "name" => "Visit /register",
                 "total_count" => 1,
                 "prop_names" => nil
               },
               %{
                 "conversion_rate" => 12.5,
                 "count" => 1,
                 "name" => "Visit /signup/*",
                 "total_count" => 1,
                 "prop_names" => nil
               }
             ]
    end
  end
end
