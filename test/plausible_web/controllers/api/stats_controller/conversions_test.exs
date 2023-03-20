defmodule PlausibleWeb.Api.StatsController.ConversionsTest do
  use PlausibleWeb.ConnCase

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

    test "returns conversions when a direct :is filter on event prop", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          user_id: @user_id,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["100", "true"]
        ),
        build(:event,
          user_id: @user_id,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["500", "true"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["100", "false"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["amount"],
          "meta.value": ["200"]
        )
      ])

      insert(:goal, %{domain: site.domain, event_name: "Payment"})

      filters = Jason.encode!(%{props: %{"logged_in" => "true"}})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Payment",
                 "unique_conversions" => 1,
                 "total_conversions" => 2,
                 "prop_names" => nil,
                 "conversion_rate" => 33.3
               }
             ]
    end

    test "returns conversions when a direct :is_not filter on event prop", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          user_id: @user_id,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["100", "true"]
        ),
        build(:event,
          user_id: @user_id,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["500", "true"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["100", "false"]
        ),
        build(:event, name: "Payment")
      ])

      insert(:goal, %{domain: site.domain, event_name: "Payment"})

      filters = Jason.encode!(%{props: %{"logged_in" => "!true"}})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Payment",
                 "unique_conversions" => 2,
                 "total_conversions" => 2,
                 "prop_names" => nil,
                 "conversion_rate" => 66.7
               }
             ]
    end

    test "returns conversions when a direct :is (none) filter on event prop", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          user_id: @user_id,
          name: "Payment"
        ),
        build(:event,
          user_id: @user_id,
          name: "Payment",
          "meta.key": ["amount"],
          "meta.value": ["500"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["100", "false"]
        ),
        build(:event, name: "Payment")
      ])

      insert(:goal, %{domain: site.domain, event_name: "Payment"})

      filters = Jason.encode!(%{props: %{"logged_in" => "(none)"}})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Payment",
                 "unique_conversions" => 2,
                 "total_conversions" => 3,
                 "prop_names" => nil,
                 "conversion_rate" => 66.7
               }
             ]
    end

    test "returns conversions when a direct :is_not (none) filter on event prop", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          user_id: @user_id,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["500", "false"]
        ),
        build(:event,
          user_id: @user_id,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["500", "true"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["100", "false"]
        ),
        build(:event, name: "Payment")
      ])

      insert(:goal, %{domain: site.domain, event_name: "Payment"})

      filters = Jason.encode!(%{props: %{"logged_in" => "!(none)"}})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Payment",
                 "unique_conversions" => 2,
                 "total_conversions" => 3,
                 "prop_names" => nil,
                 "conversion_rate" => 66.7
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/conversions - with goal filter" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns only the conversion that is filtered for", %{conn: conn, site: site} do
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

    test "can filter by multiple mixed goals", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/another"),
        build(:pageview, pathname: "/register"),
        build(:event, name: "Signup"),
        build(:event, name: "Signup")
      ])

      insert(:goal, %{domain: site.domain, page_path: "/register"})
      insert(:goal, %{domain: site.domain, event_name: "Signup"})

      filters = Jason.encode!(%{goal: "Signup|Visit /register"})

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
                 "prop_names" => nil,
                 "conversion_rate" => 33.3
               },
               %{
                 "name" => "Visit /register",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "prop_names" => nil,
                 "conversion_rate" => 16.7
               }
             ]
    end

    test "can filter by multiple negated mixed goals", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/another"),
        build(:pageview, pathname: "/register"),
        build(:event, name: "CTA"),
        build(:event, name: "Signup")
      ])

      insert(:goal, %{domain: site.domain, page_path: "/register"})
      insert(:goal, %{domain: site.domain, page_path: "/another"})
      insert(:goal, %{domain: site.domain, event_name: "CTA"})
      insert(:goal, %{domain: site.domain, event_name: "Signup"})

      filters = Jason.encode!(%{goal: "!Signup|Visit /another"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "CTA",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "prop_names" => nil,
                 "conversion_rate" => 16.7
               },
               %{
                 "name" => "Visit /register",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "prop_names" => nil,
                 "conversion_rate" => 16.7
               }
             ]
    end

    test "can filter by matches_member filter type on goals", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/another"),
        build(:pageview, pathname: "/blog/post-1"),
        build(:pageview, pathname: "/blog/post-2"),
        build(:event, name: "CTA"),
        build(:event, name: "Signup")
      ])

      insert(:goal, %{domain: site.domain, page_path: "/blog**"})
      insert(:goal, %{domain: site.domain, event_name: "CTA"})
      insert(:goal, %{domain: site.domain, event_name: "Signup"})

      filters = Jason.encode!(%{goal: "Signup|Visit /blog**"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Visit /blog**",
                 "unique_conversions" => 2,
                 "total_conversions" => 2,
                 "prop_names" => nil,
                 "conversion_rate" => 33.3
               },
               %{
                 "name" => "Signup",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "prop_names" => nil,
                 "conversion_rate" => 16.7
               }
             ]
    end

    test "can filter by not_matches_member filter type on goals", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/another"),
        build(:pageview, pathname: "/another"),
        build(:pageview, pathname: "/blog/post-1"),
        build(:pageview, pathname: "/blog/post-2"),
        build(:event, name: "CTA"),
        build(:event, name: "Signup")
      ])

      insert(:goal, %{domain: site.domain, page_path: "/blog**"})
      insert(:goal, %{domain: site.domain, page_path: "/ano**"})
      insert(:goal, %{domain: site.domain, event_name: "CTA"})
      insert(:goal, %{domain: site.domain, event_name: "Signup"})

      filters = Jason.encode!(%{goal: "!Signup|Visit /blog**"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Visit /ano**",
                 "unique_conversions" => 2,
                 "total_conversions" => 2,
                 "prop_names" => nil,
                 "conversion_rate" => 33.3
               },
               %{
                 "name" => "CTA",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "prop_names" => nil,
                 "conversion_rate" => 16.7
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/conversions - with goal and prop=(none) filter" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns only the conversion that is filtered for", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/", user_id: 1),
        build(:pageview, pathname: "/", user_id: 2),
        build(:event, name: "Signup", user_id: 1, "meta.key": ["variant"], "meta.value": ["A"]),
        build(:event, name: "Signup", user_id: 2)
      ])

      insert(:goal, %{domain: site.domain, event_name: "Signup"})

      filters = Jason.encode!(%{goal: "Signup", props: %{variant: "(none)"}})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Signup",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "prop_names" => ["variant"],
                 "conversion_rate" => 50
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

    test "Property breakdown with prop and goal filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, utm_campaign: "campaignA"),
        build(:event,
          user_id: 1,
          name: "ButtonClick",
          "meta.key": ["variant"],
          "meta.value": ["A"]
        ),
        build(:pageview, user_id: 2, utm_campaign: "campaignA"),
        build(:event,
          user_id: 2,
          name: "ButtonClick",
          "meta.key": ["variant"],
          "meta.value": ["B"]
        )
      ])

      insert(:goal, %{domain: site.domain, event_name: "ButtonClick"})

      filters =
        Jason.encode!(%{
          goal: "ButtonClick",
          props: %{variant: "A"},
          utm_campaign: "campaignA"
        })

      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "A",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end

    test "Property breakdown with goal and source filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, referrer_source: "Google"),
        build(:event,
          user_id: 1,
          name: "ButtonClick",
          "meta.key": ["variant"],
          "meta.value": ["A"]
        ),
        build(:pageview, user_id: 2, referrer_source: "Google"),
        build(:pageview, user_id: 3, referrer_source: "ignore"),
        build(:event,
          user_id: 3,
          name: "ButtonClick",
          "meta.key": ["variant"],
          "meta.value": ["B"]
        )
      ])

      insert(:goal, %{domain: site.domain, event_name: "ButtonClick"})

      filters =
        Jason.encode!(%{
          goal: "ButtonClick",
          source: "Google"
        })

      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "A",
                 "unique_conversions" => 1,
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
