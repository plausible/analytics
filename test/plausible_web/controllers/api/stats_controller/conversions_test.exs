defmodule PlausibleWeb.Api.StatsController.ConversionsTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils
  @user_id 123

  describe "GET /api/stats/:domain/conversions" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns mixed conversions in ordered by count", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/register"),
        build(:pageview, pathname: "/register"),
        build(:event, name: "Signup", "meta.key": ["variant"], "meta.value": ["A"]),
        build(:event,
          user_id: @user_id,
          name: "Signup",
          "meta.key": ["variant"],
          "meta.value": ["A"]
        ),
        build(:event,
          user_id: @user_id,
          name: "Signup",
          "meta.key": ["variant"],
          "meta.value": ["B"]
        )
      ])

      insert(:goal, %{domain: site.domain, page_path: "/register"})
      insert(:goal, %{domain: site.domain, event_name: "Signup"})

      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Signup",
                 "unique_conversions" => 2,
                 "total_conversions" => 3,
                 "prop_names" => nil,
                 "conversion_rate" => 33.3
               },
               %{
                 "name" => "Visit /register",
                 "unique_conversions" => 2,
                 "total_conversions" => 2,
                 "prop_names" => nil,
                 "conversion_rate" => 33.3
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/conversions - with goal filter" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns only the conversion tha is filtered for", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/register"),
        build(:pageview, pathname: "/register"),
        build(:event, name: "Signup", "meta.key": ["variant"], "meta.value": ["A"]),
        build(:event, name: "Signup", "meta.key": ["variant"], "meta.value": ["B"])
      ])

      insert(:goal, %{domain: site.domain, page_path: "/register"})
      insert(:goal, %{domain: site.domain, event_name: "Signup"})

      filters = Jason.encode!(%{goal: "Signup"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Signup",
                 "unique_conversions" => 2,
                 "total_conversions" => 2,
                 "prop_names" => ["variant"],
                 "conversion_rate" => 33.3
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/property/:key" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns property breakdown for goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/register"),
        build(:event, name: "Signup", "meta.key": ["variant"], "meta.value": ["A"]),
        build(:event, name: "Signup", "meta.key": ["variant"], "meta.value": ["B"]),
        build(:event, name: "Signup", "meta.key": ["variant"], "meta.value": ["B"])
      ])

      insert(:goal, %{domain: site.domain, event_name: "Signup"})
      filters = Jason.encode!(%{goal: "Signup"})
      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "unique_conversions" => 2,
                 "name" => "B",
                 "total_conversions" => 2,
                 "conversion_rate" => 33.3
               },
               %{
                 "unique_conversions" => 1,
                 "name" => "A",
                 "total_conversions" => 1,
                 "conversion_rate" => 16.7
               }
             ]
    end

    test "returns (none) values in property breakdown for goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/register"),
        build(:event, name: "Signup"),
        build(:event, name: "Signup"),
        build(:event, name: "Signup", "meta.key": ["variant"], "meta.value": ["A"])
      ])

      insert(:goal, %{domain: site.domain, event_name: "Signup"})
      filters = Jason.encode!(%{goal: "Signup"})
      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "unique_conversions" => 2,
                 "name" => "(none)",
                 "total_conversions" => 2,
                 "conversion_rate" => 33.3
               },
               %{
                 "unique_conversions" => 1,
                 "name" => "A",
                 "total_conversions" => 1,
                 "conversion_rate" => 16.7
               }
             ]
    end

    test "property breakdown with prop filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1),
        build(:event, user_id: 1, name: "Signup", "meta.key": ["variant"], "meta.value": ["A"]),
        build(:pageview, user_id: 2),
        build(:event, user_id: 2, name: "Signup", "meta.key": ["variant"], "meta.value": ["B"])
      ])

      insert(:goal, %{domain: site.domain, event_name: "Signup"})
      filters = Jason.encode!(%{goal: "Signup", props: %{"variant" => "B"}})
      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "unique_conversions" => 1,
                 "name" => "B",
                 "total_conversions" => 1,
                 "conversion_rate" => 50.0
               }
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
                 "unique_conversions" => 8,
                 "name" => "Visit /**",
                 "total_conversions" => 8,
                 "prop_names" => nil
               },
               %{
                 "conversion_rate" => 37.5,
                 "unique_conversions" => 3,
                 "name" => "Visit /*",
                 "total_conversions" => 3,
                 "prop_names" => nil
               },
               %{
                 "conversion_rate" => 37.5,
                 "unique_conversions" => 3,
                 "name" => "Visit /signup/**",
                 "total_conversions" => 3,
                 "prop_names" => nil
               },
               %{
                 "conversion_rate" => 25.0,
                 "unique_conversions" => 2,
                 "name" => "Visit /billing**/success",
                 "total_conversions" => 2,
                 "prop_names" => nil
               },
               %{
                 "conversion_rate" => 25.0,
                 "unique_conversions" => 2,
                 "name" => "Visit /reg*",
                 "total_conversions" => 2,
                 "prop_names" => nil
               },
               %{
                 "conversion_rate" => 12.5,
                 "unique_conversions" => 1,
                 "name" => "Visit /billing*/success",
                 "total_conversions" => 1,
                 "prop_names" => nil
               },
               %{
                 "conversion_rate" => 12.5,
                 "unique_conversions" => 1,
                 "name" => "Visit /register",
                 "total_conversions" => 1,
                 "prop_names" => nil
               },
               %{
                 "conversion_rate" => 12.5,
                 "unique_conversions" => 1,
                 "name" => "Visit /signup/*",
                 "total_conversions" => 1,
                 "prop_names" => nil
               }
             ]
    end
  end
end
