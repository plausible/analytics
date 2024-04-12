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
                 "conversion_rate" => 33.3
               },
               %{
                 "name" => "Visit /register",
                 "visitors" => 2,
                 "events" => 2,
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

    test "filtering by session attribute and multiple goals", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          user_id: @user_id,
          name: "Payment",
          browser: "Firefox"
        ),
        build(:event,
          user_id: @user_id,
          name: "Payment",
          browser: "Firefox"
        ),
        build(:event,
          name: "Payment",
          browser: "Chrome"
        ),
        build(:event, name: "Payment"),
        build(:pageview, browser: "Firefox", pathname: "/"),
        build(:pageview, browser: "Firefox", pathname: "/register")
      ])

      insert(:goal, %{site: site, event_name: "Payment"})
      insert(:goal, %{site: site, page_path: "/register"})

      filters = Jason.encode!(%{browser: "Firefox"})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Payment",
                 "visitors" => 1,
                 "events" => 2,
                 "conversion_rate" => 33.3
               },
               %{
                 "name" => "Visit /register",
                 "visitors" => 1,
                 "events" => 1,
                 "conversion_rate" => 33.3
               }
             ]
    end

    @tag :full_build_only
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
                 "conversion_rate" => 100.0,
                 "average_revenue" => %{"short" => "€166.7M", "long" => "€166,733,566.75"},
                 "total_revenue" => %{"short" => "€500.2M", "long" => "€500,200,700.25"}
               }
             ]
    end

    @tag :full_build_only
    test "returns revenue goals as custom events if the plan doesn't cover the feature", %{
      conn: conn,
      site: site,
      user: user
    } do
      user
      |> Plausible.Auth.User.end_trial()
      |> Plausible.Repo.update!()

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
                 "conversion_rate" => 100.0
               }
             ]
    end

    @tag :full_build_only
    test "returns revenue metrics as nil for non-revenue goals", %{
      conn: conn,
      site: site
    } do
      [
        build(:event,
          name: "Payment",
          pathname: "/checkout",
          revenue_reporting_amount: Decimal.new("10.00"),
          revenue_reporting_currency: "EUR"
        )
      ]
      |> Enum.concat(build_list(2, :event, name: "Signup"))
      |> Enum.concat(build_list(3, :pageview, pathname: "/checkout"))
      |> then(fn events -> populate_stats(site, events) end)

      insert(:goal, %{site: site, event_name: "Signup"})
      insert(:goal, %{site: site, page_path: "/checkout"})
      insert(:goal, %{site: site, event_name: "Payment", currency: :EUR})

      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day")
      response = json_response(conn, 200)

      assert [
               %{
                 "average_revenue" => %{"long" => "€10.00", "short" => "€10.0"},
                 "conversion_rate" => 16.7,
                 "name" => "Payment",
                 "events" => 1,
                 "total_revenue" => %{"long" => "€10.00", "short" => "€10.0"},
                 "visitors" => 1
               },
               %{
                 "average_revenue" => nil,
                 "conversion_rate" => 33.3,
                 "name" => "Signup",
                 "events" => 2,
                 "total_revenue" => nil,
                 "visitors" => 2
               },
               %{
                 "average_revenue" => nil,
                 "conversion_rate" => 50.0,
                 "name" => "Visit /checkout",
                 "events" => 3,
                 "total_revenue" => nil,
                 "visitors" => 3
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
                 "conversion_rate" => 100.0
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/conversions - with goal filter" do
    setup [:create_user, :log_in, :create_new_site]

    test "does not consider custom event pathname as a pageview goal completion", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/register"),
        build(:event, pathname: "/register", name: "Signup")
      ])

      insert(:goal, %{site: site, page_path: "/register"})
      insert(:goal, %{site: site, event_name: "Signup"})

      get_with_filter = fn filters ->
        path = "/api/stats/#{site.domain}/conversions"
        query = "?period=day&filters=#{Jason.encode!(filters)}"

        get(conn, path <> query)
        |> json_response(200)
      end

      expected = [
        %{
          "name" => "Signup",
          "visitors" => 1,
          "events" => 1,
          "conversion_rate" => 33.3
        }
      ]

      # {:is, {:event, event}} filter type
      assert get_with_filter.(%{goal: "Signup"}) == expected

      # {:member, clauses} filter type
      assert get_with_filter.(%{goal: "Signup|Whatever"}) == expected

      # {:matches_member, clauses} filter type
      assert get_with_filter.(%{goal: "Signup|Visit /whatever*"}) == expected
    end

    test "does not return custom events with the filtered pageview goal pathname", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/register"),
        build(:event, pathname: "/register", name: "Signup")
      ])

      insert(:goal, %{site: site, page_path: "/register"})
      insert(:goal, %{site: site, page_path: "/regi**"})
      insert(:goal, %{site: site, event_name: "Signup"})

      get_with_filter = fn filters ->
        path = "/api/stats/#{site.domain}/conversions"
        query = "?period=day&filters=#{Jason.encode!(filters)}"

        get(conn, path <> query)
        |> json_response(200)
      end

      expected = [
        %{
          "name" => "Visit /register",
          "visitors" => 1,
          "events" => 1,
          "conversion_rate" => 33.3
        },
        %{
          "name" => "Visit /regi**",
          "visitors" => 1,
          "events" => 1,
          "conversion_rate" => 33.3
        }
      ]

      # {:is, {:page, path}} filter type
      assert get_with_filter.(%{goal: "Visit+/register"}) == expected

      # {:matches, {:page, expr}} filter type
      assert get_with_filter.(%{goal: "Visit+/regi**"}) == expected

      # {:member, clauses} filter type
      assert get_with_filter.(%{goal: "Visit+/register|Whatever"}) == expected

      # {:matches_member, clauses} filter type
      assert get_with_filter.(%{goal: "Visit+/register|Visit+/regi**"}) == expected
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
                 "conversion_rate" => 33.3
               },
               %{
                 "name" => "Visit /register",
                 "visitors" => 1,
                 "events" => 1,
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
                 "conversion_rate" => 66.7
               },
               %{
                 "name" => "Visit /billing/upgrade",
                 "visitors" => 1,
                 "events" => 1,
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
                 "conversion_rate" => 33.3
               },
               %{
                 "name" => "Signup",
                 "visitors" => 1,
                 "events" => 1,
                 "conversion_rate" => 16.7
               }
             ]
    end

    test "conversion_rate for goals should not be calculated with imported data", %{
      conn: conn,
      site: site
    } do
      site_import =
        insert(:site_import,
          start_date: ~D[2005-01-01],
          end_date: Timex.today(),
          source: :universal_analytics
        )

      populate_stats(site, site_import.id, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/another"),
        build(:pageview, pathname: "/blog/post-1"),
        build(:pageview, pathname: "/blog/post-2"),
        build(:imported_pages, page: "/blog/post-1"),
        build(:imported_visitors)
      ])

      insert(:goal, %{site: site, page_path: "/blog**"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Visit /blog**",
                 "visitors" => 2,
                 "events" => 2,
                 "conversion_rate" => 50
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
      insert(:goal, %{site: site, page_path: "/billing*/success"})
      insert(:goal, %{site: site, page_path: "/signup"})
      insert(:goal, %{site: site, page_path: "/signup/*"})
      insert(:goal, %{site: site, page_path: "/*"})

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
                 "name" => "Visit /*",
                 "events" => 8
               },
               %{
                 "conversion_rate" => 37.5,
                 "visitors" => 3,
                 "name" => "Visit /signup/*",
                 "events" => 3
               },
               %{
                 "conversion_rate" => 25.0,
                 "visitors" => 2,
                 "name" => "Visit /billing*/success",
                 "events" => 2
               },
               %{
                 "conversion_rate" => 25.0,
                 "visitors" => 2,
                 "name" => "Visit /reg*",
                 "events" => 2
               },
               %{
                 "conversion_rate" => 12.5,
                 "visitors" => 1,
                 "name" => "Visit /register",
                 "events" => 1
               }
             ]
    end
  end
end
