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

      insert(:goal, %{site: site, page_path: "/register"})
      insert(:goal, %{site: site, event_name: "Signup"})

      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Signup",
                 "visitors" => 2,
                 "events" => 3,
                 "prop_names" => [],
                 "conversion_rate" => 33.3
               },
               %{
                 "name" => "Visit /register",
                 "visitors" => 2,
                 "events" => 2,
                 "prop_names" => [],
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

      insert(:goal, %{site: site, event_name: "Payment"})

      filters = Jason.encode!(%{props: %{"logged_in" => "true"}})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Payment",
                 "visitors" => 1,
                 "events" => 2,
                 "prop_names" => [],
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

      insert(:goal, %{site: site, event_name: "Payment"})

      filters = Jason.encode!(%{props: %{"logged_in" => "!true"}})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Payment",
                 "visitors" => 2,
                 "events" => 2,
                 "prop_names" => [],
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

      insert(:goal, %{site: site, event_name: "Payment"})

      filters = Jason.encode!(%{props: %{"logged_in" => "(none)"}})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Payment",
                 "visitors" => 2,
                 "events" => 3,
                 "prop_names" => [],
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

      insert(:goal, %{site: site, event_name: "Payment"})

      filters = Jason.encode!(%{props: %{"logged_in" => "!(none)"}})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Payment",
                 "visitors" => 2,
                 "events" => 3,
                 "prop_names" => [],
                 "conversion_rate" => 66.7
               }
             ]
    end

    test "garbage filters don't crash the call", %{conn: conn, site: site} do
      filters =
        "{\"source\":\"Direct / None\",\"screen\":\"Desktop\",\"browser\":\"Chrome\",\"os\":\"Mac\",\"os_version\":\"10.15\",\"country\":\"DE\",\"city\":\"2950159\"}%' AND 2*3*8=6*8 AND 'L9sv'!='L9sv%"

      resp =
        conn
        |> get("/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")
        |> json_response(200)

      assert resp == []
    end

    test "returns formatted average and total values for a conversion with revenue value", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("200100300.123"),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("300100400.123"),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("0"),
          revenue_reporting_currency: "USD"
        ),
        build(:event, name: "Payment", revenue_reporting_amount: nil),
        build(:event, name: "Payment", revenue_reporting_amount: nil)
      ])

      insert(:goal, %{site: site, event_name: "Payment", currency: :EUR})

      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Payment",
                 "visitors" => 5,
                 "events" => 5,
                 "prop_names" => [],
                 "conversion_rate" => 100.0,
                 "average_revenue" => %{"short" => "€166.7M", "long" => "€166,733,566.75"},
                 "total_revenue" => %{"short" => "€500.2M", "long" => "€500,200,700.25"}
               }
             ]
    end

    test "returns revenue metrics as nil for non-revenue goals", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event, name: "Signup"),
        build(:event, name: "Signup"),
        build(:event,
          name: "Payment",
          pathname: "/checkout",
          revenue_reporting_amount: Decimal.new("10.00"),
          revenue_reporting_currency: "EUR"
        )
      ])

      insert(:goal, %{site: site, event_name: "Signup"})
      insert(:goal, %{site: site, page_path: "/checkout"})
      insert(:goal, %{site: site, event_name: "Payment", currency: :EUR})

      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day")
      response = json_response(conn, 200)

      assert [
               %{
                 "average_revenue" => %{"long" => "€10.00", "short" => "€10.0"},
                 "conversion_rate" => 33.3,
                 "name" => "Payment",
                 "prop_names" => [],
                 "events" => 1,
                 "total_revenue" => %{"long" => "€10.00", "short" => "€10.0"},
                 "visitors" => 1
               },
               %{
                 "average_revenue" => nil,
                 "conversion_rate" => 66.7,
                 "name" => "Signup",
                 "prop_names" => [],
                 "events" => 2,
                 "total_revenue" => nil,
                 "visitors" => 2
               },
               %{
                 "average_revenue" => nil,
                 "conversion_rate" => 33.3,
                 "name" => "Visit /checkout",
                 "prop_names" => [],
                 "events" => 1,
                 "total_revenue" => nil,
                 "visitors" => 1
               }
             ] == Enum.sort_by(response, & &1["name"])
    end

    test "does not return revenue metrics if no revenue goals are returned", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event, name: "Signup")
      ])

      insert(:goal, %{site: site, event_name: "Signup"})

      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Signup",
                 "visitors" => 1,
                 "events" => 1,
                 "prop_names" => [],
                 "conversion_rate" => 100.0
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

      insert(:goal, %{site: site, page_path: "/register"})
      insert(:goal, %{site: site, event_name: "Signup"})

      filters = Jason.encode!(%{goal: "Signup"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Signup",
                 "visitors" => 2,
                 "events" => 2,
                 "prop_names" => ["variant"],
                 "conversion_rate" => 33.3
               }
             ]
    end

    test "returns only the prop name for the property in filter", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Payment",
          "meta.key": ["logged_in"],
          "meta.value": ["true"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["logged_in"],
          "meta.value": ["false"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["author"],
          "meta.value": ["John"]
        )
      ])

      insert(:goal, %{site: site, event_name: "Payment"})

      filters = Jason.encode!(%{goal: "Payment", props: %{"logged_in" => "true|(none)"}})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Payment",
                 "visitors" => 2,
                 "events" => 2,
                 "prop_names" => ["logged_in"],
                 "conversion_rate" => 66.7
               }
             ]
    end

    test "returns prop_names=[] when goal :member + property filter are applied at the same time",
         %{
           conn: conn,
           site: site
         } do
      populate_stats(site, [
        build(:event,
          name: "Payment",
          "meta.key": ["logged_in"],
          "meta.value": ["true"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["logged_in"],
          "meta.value": ["false"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["author"],
          "meta.value": ["John"]
        )
      ])

      insert(:goal, %{site: site, event_name: "Payment"})
      insert(:goal, %{site: site, event_name: "Signup"})

      filters = Jason.encode!(%{goal: "Payment|Signup", props: %{"logged_in" => "true|(none)"}})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")

      assert [%{"prop_names" => []}] = json_response(conn, 200)
    end

    test "filters out garbage prop_names", %{conn: conn, site: site} do
      {:ok, site} = Plausible.Props.allow(site, ["author"])

      populate_stats(site, [
        build(:event,
          name: "Payment",
          "meta.key": ["author"],
          "meta.value": ["Valdis"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["Garbage"],
          "meta.value": ["321"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["OnlyGarbage"],
          "meta.value": ["123"]
        )
      ])

      insert(:goal, %{site: site, event_name: "Payment"})

      filters = Jason.encode!(%{goal: "Payment"})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")

      assert [%{"prop_names" => ["author"]}] = json_response(conn, 200)
    end

    test "filters out garbage prop_names when session filters are applied",
         %{
           conn: conn,
           site: site
         } do
      {:ok, site} = Plausible.Props.allow(site, ["author", "logged_in"])

      populate_stats(site, [
        build(:event,
          name: "Payment",
          pathname: "/",
          "meta.key": ["author"],
          "meta.value": ["Valdis"]
        ),
        build(:event,
          name: "Payment",
          pathname: "/ignore",
          "meta.key": ["logged_in"],
          "meta.value": ["true"]
        ),
        build(:event,
          name: "Payment",
          pathname: "/",
          "meta.key": ["garbage"],
          "meta.value": ["123"]
        )
      ])

      insert(:goal, %{site: site, event_name: "Payment"})

      filters = Jason.encode!(%{goal: "Payment", entry_page: "/"})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")

      assert [%{"prop_names" => ["author"]}] = json_response(conn, 200)
    end

    test "does not filter any prop names by default (when site.allowed_event_props is nil)",
         %{
           conn: conn,
           site: site
         } do
      populate_stats(site, [
        build(:event,
          name: "Payment",
          "meta.key": ["Garbage"],
          "meta.value": ["321"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["OnlyGarbage"],
          "meta.value": ["123"]
        )
      ])

      insert(:goal, %{site: site, event_name: "Payment"})

      filters = Jason.encode!(%{goal: "Payment"})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")

      assert [%{"prop_names" => prop_names}] = json_response(conn, 200)
      assert "Garbage" in prop_names
      assert "OnlyGarbage" in prop_names
    end

    test "does not filter out special prop keys", %{conn: conn, site: site} do
      {:ok, site} = Plausible.Props.allow(site, ["author"])

      populate_stats(site, [
        build(:event,
          name: "Outbound Link: Click",
          "meta.key": ["url", "path", "first_time_customer"],
          "meta.value": ["http://link.test", "/abc", "true"]
        )
      ])

      insert(:goal, %{site: site, event_name: "Outbound Link: Click"})

      filters = Jason.encode!(%{goal: "Outbound Link: Click"})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")
      assert [%{"prop_names" => ["url", "path"]}] = json_response(conn, 200)
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

      insert(:goal, %{site: site, page_path: "/register"})
      insert(:goal, %{site: site, event_name: "Signup"})

      filters = Jason.encode!(%{goal: "Signup|Visit /register"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Signup",
                 "visitors" => 2,
                 "events" => 2,
                 "prop_names" => [],
                 "conversion_rate" => 33.3
               },
               %{
                 "name" => "Visit /register",
                 "visitors" => 1,
                 "events" => 1,
                 "prop_names" => [],
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

      insert(:goal, %{site: site, page_path: "/register"})
      insert(:goal, %{site: site, page_path: "/another"})
      insert(:goal, %{site: site, event_name: "CTA"})
      insert(:goal, %{site: site, event_name: "Signup"})

      filters = Jason.encode!(%{goal: "!Signup|Visit /another"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "CTA",
                 "visitors" => 1,
                 "events" => 1,
                 "prop_names" => [],
                 "conversion_rate" => 16.7
               },
               %{
                 "name" => "Visit /register",
                 "visitors" => 1,
                 "events" => 1,
                 "prop_names" => [],
                 "conversion_rate" => 16.7
               }
             ]
    end

    test "can combine wildcard and no wildcard in matches_member", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/blog/post-1"),
        build(:pageview, pathname: "/blog/post-2"),
        build(:pageview, pathname: "/billing/upgrade")
      ])

      insert(:goal, %{site: site, page_path: "/blog/**"})
      insert(:goal, %{site: site, page_path: "/billing/upgrade"})

      filters = Jason.encode!(%{goal: "Visit /blog/**|Visit /billing/upgrade"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Visit /blog/**",
                 "visitors" => 2,
                 "events" => 2,
                 "prop_names" => [],
                 "conversion_rate" => 66.7
               },
               %{
                 "name" => "Visit /billing/upgrade",
                 "visitors" => 1,
                 "events" => 1,
                 "prop_names" => [],
                 "conversion_rate" => 33.3
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

      insert(:goal, %{site: site, page_path: "/blog**"})
      insert(:goal, %{site: site, event_name: "CTA"})
      insert(:goal, %{site: site, event_name: "Signup"})

      filters = Jason.encode!(%{goal: "Signup|Visit /blog**"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Visit /blog**",
                 "visitors" => 2,
                 "events" => 2,
                 "prop_names" => [],
                 "conversion_rate" => 33.3
               },
               %{
                 "name" => "Signup",
                 "visitors" => 1,
                 "events" => 1,
                 "prop_names" => [],
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

      insert(:goal, %{site: site, page_path: "/blog**"})
      insert(:goal, %{site: site, page_path: "/ano**"})
      insert(:goal, %{site: site, event_name: "CTA"})
      insert(:goal, %{site: site, event_name: "Signup"})

      filters = Jason.encode!(%{goal: "!Signup|Visit /blog**"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Visit /ano**",
                 "visitors" => 2,
                 "events" => 2,
                 "prop_names" => [],
                 "conversion_rate" => 33.3
               },
               %{
                 "name" => "CTA",
                 "visitors" => 1,
                 "events" => 1,
                 "prop_names" => [],
                 "conversion_rate" => 16.7
               }
             ]
    end

    test "can combine wildcard and no wildcard in not_matches_member", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/blog/post-1"),
        build(:pageview, pathname: "/blog/post-2"),
        build(:pageview, pathname: "/billing/upgrade"),
        build(:pageview, pathname: "/register")
      ])

      insert(:goal, %{site: site, page_path: "/blog/**"})
      insert(:goal, %{site: site, page_path: "/billing/upgrade"})
      insert(:goal, %{site: site, page_path: "/register"})

      filters = Jason.encode!(%{goal: "!Visit /blog/**|Visit /billing/upgrade"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Visit /register",
                 "visitors" => 1,
                 "events" => 1,
                 "prop_names" => [],
                 "conversion_rate" => 25
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

      insert(:goal, %{site: site, event_name: "Signup"})

      filters = Jason.encode!(%{goal: "Signup", props: %{variant: "(none)"}})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Signup",
                 "visitors" => 1,
                 "events" => 1,
                 "prop_names" => ["variant"],
                 "conversion_rate" => 50
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/conversions - with glob goals" do
    setup [:create_user, :log_in, :create_site]

    test "returns correct and sorted glob goal counts", %{conn: conn, site: site} do
      insert(:goal, %{site: site, page_path: "/register"})
      insert(:goal, %{site: site, page_path: "/reg*"})
      insert(:goal, %{site: site, page_path: "/*/register"})
      insert(:goal, %{site: site, page_path: "/billing**/success"})
      insert(:goal, %{site: site, page_path: "/billing*/success"})
      insert(:goal, %{site: site, page_path: "/signup"})
      insert(:goal, %{site: site, page_path: "/signup/*"})
      insert(:goal, %{site: site, page_path: "/signup/**"})
      insert(:goal, %{site: site, page_path: "/*"})
      insert(:goal, %{site: site, page_path: "/**"})

      populate_stats(site, [
        build(:pageview,
          pathname: "/hum",
          timestamp: ~N[2019-07-01 23:00:00]
        ),
        build(:pageview,
          pathname: "/register",
          timestamp: ~N[2019-07-01 23:00:00]
        ),
        build(:pageview,
          pathname: "/reg",
          timestamp: ~N[2019-07-01 23:00:00]
        ),
        build(:pageview,
          pathname: "/billing/success",
          timestamp: ~N[2019-07-01 23:00:00]
        ),
        build(:pageview,
          pathname: "/billing/upgrade/success",
          timestamp: ~N[2019-07-01 23:00:00]
        ),
        build(:pageview,
          pathname: "/signup/new",
          timestamp: ~N[2019-07-01 23:00:00]
        ),
        build(:pageview,
          pathname: "/signup/new/2",
          timestamp: ~N[2019-07-01 23:00:00]
        ),
        build(:pageview,
          pathname: "/signup/new/3",
          timestamp: ~N[2019-07-01 23:00:00]
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&date=2019-07-01"
        )

      assert json_response(conn, 200) == [
               %{
                 "conversion_rate" => 100.0,
                 "visitors" => 8,
                 "name" => "Visit /**",
                 "events" => 8,
                 "prop_names" => []
               },
               %{
                 "conversion_rate" => 37.5,
                 "visitors" => 3,
                 "name" => "Visit /signup/**",
                 "events" => 3,
                 "prop_names" => []
               },
               %{
                 "conversion_rate" => 37.5,
                 "visitors" => 3,
                 "name" => "Visit /*",
                 "events" => 3,
                 "prop_names" => []
               },
               %{
                 "conversion_rate" => 25.0,
                 "visitors" => 2,
                 "name" => "Visit /billing**/success",
                 "events" => 2,
                 "prop_names" => []
               },
               %{
                 "conversion_rate" => 25.0,
                 "visitors" => 2,
                 "name" => "Visit /reg*",
                 "events" => 2,
                 "prop_names" => []
               },
               %{
                 "conversion_rate" => 12.5,
                 "visitors" => 1,
                 "name" => "Visit /signup/*",
                 "events" => 1,
                 "prop_names" => []
               },
               %{
                 "conversion_rate" => 12.5,
                 "visitors" => 1,
                 "name" => "Visit /billing*/success",
                 "events" => 1,
                 "prop_names" => []
               },
               %{
                 "conversion_rate" => 12.5,
                 "visitors" => 1,
                 "name" => "Visit /register",
                 "events" => 1,
                 "prop_names" => []
               }
             ]
    end

    test "returns prop names when filtered by glob goal", %{conn: conn, site: site} do
      insert(:goal, %{site: site, page_path: "/register**"})

      populate_stats(site, [
        build(:pageview,
          pathname: "/register",
          "meta.key": ["logged_in"],
          "meta.value": ["false"],
          timestamp: ~N[2019-07-01 23:00:00]
        ),
        build(:pageview,
          pathname: "/register-success",
          "meta.key": ["logged_in", "author"],
          "meta.value": ["true", "John"],
          timestamp: ~N[2019-07-01 23:00:00]
        )
      ])

      filters = Jason.encode!(%{goal: "Visit /register**"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&date=2019-07-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "conversion_rate" => 100.0,
                 "visitors" => 2,
                 "name" => "Visit /register**",
                 "events" => 2,
                 "prop_names" => ["logged_in", "author"]
               }
             ]
    end
  end
end
