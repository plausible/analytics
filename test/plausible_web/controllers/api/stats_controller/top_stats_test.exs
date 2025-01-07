defmodule PlausibleWeb.Api.StatsController.TopStatsTest do
  use PlausibleWeb.ConnCase
  use Plausible.Teams.Test

  @user_id Enum.random(1000..9999)

  describe "GET /api/stats/top-stats - default" do
    setup [:create_user, :log_in, :create_site]

    test "returns graph_metric key for graphable top stats", %{conn: conn, site: site} do
      [visitors, visits, pageviews, views_per_visit, bounce_rate, visit_duration] =
        conn
        |> get("/api/stats/#{site.domain}/top-stats")
        |> json_response(200)
        |> Map.get("top_stats")

      assert %{"graph_metric" => "visitors"} = visitors
      assert %{"graph_metric" => "visits"} = visits
      assert %{"graph_metric" => "pageviews"} = pageviews
      assert %{"graph_metric" => "views_per_visit"} = views_per_visit
      assert %{"graph_metric" => "bounce_rate"} = bounce_rate
      assert %{"graph_metric" => "visit_duration"} = visit_duration
    end

    test "returns graph_metric key for top stats in realtime mode", %{
      conn: conn,
      site: site
    } do
      [current_visitors, unique_visitors, pageviews] =
        conn
        |> get("/api/stats/#{site.domain}/top-stats?period=realtime")
        |> json_response(200)
        |> Map.get("top_stats")

      assert %{"graph_metric" => "current_visitors"} = current_visitors
      assert %{"graph_metric" => "visitors"} = unique_visitors
      assert %{"graph_metric" => "pageviews"} = pageviews
    end

    test "counts distinct user ids", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id),
        build(:pageview, user_id: @user_id),
        build(:pageview)
      ])

      conn = get(conn, "/api/stats/#{site.domain}/top-stats?period=day")

      res = json_response(conn, 200)

      assert %{
               "name" => "Unique visitors",
               "value" => 2,
               "graph_metric" => "visitors"
             } in res["top_stats"]
    end

    test "counts total pageviews", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id),
        build(:pageview, user_id: @user_id),
        build(:pageview)
      ])

      conn = get(conn, "/api/stats/#{site.domain}/top-stats?period=day")

      res = json_response(conn, 200)

      assert %{
               "name" => "Total pageviews",
               "value" => 3,
               "graph_metric" => "pageviews"
             } in res["top_stats"]
    end

    test "experimental session count", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 3421, timestamp: ~N[2020-12-31 23:30:00]),
        build(:pageview, user_id: @user_id, timestamp: ~N[2020-12-31 23:59:00]),
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, user_id: 2, timestamp: ~N[2020-12-31 23:59:00]),
        build(:pageview, user_id: 2, timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, user_id: 617_235, timestamp: ~N[2021-01-03 00:00:00])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=day&date=2021-01-01"
        )

      res = json_response(conn, 200)

      assert res["top_stats"] == [
               %{"name" => "Unique visitors", "value" => 2, "graph_metric" => "visitors"},
               %{"name" => "Total visits", "value" => 2, "graph_metric" => "visits"},
               %{"name" => "Total pageviews", "value" => 2, "graph_metric" => "pageviews"},
               %{
                 "name" => "Views per visit",
                 "value" => 2.0,
                 "graph_metric" => "views_per_visit"
               },
               %{"name" => "Bounce rate", "value" => 0, "graph_metric" => "bounce_rate"},
               %{"name" => "Visit duration", "value" => 120, "graph_metric" => "visit_duration"}
             ]
    end

    test "counts pages per visit", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:02:00]),
        build(:pageview, timestamp: ~N[2021-01-01 15:00:00])
      ])

      conn = get(conn, "/api/stats/#{site.domain}/top-stats?period=day&date=2021-01-01")

      res = json_response(conn, 200)

      assert %{"name" => "Views per visit", "value" => 1.33, "graph_metric" => "views_per_visit"} in res[
               "top_stats"
             ]
    end

    test "calculates bounce rate", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id),
        build(:pageview, user_id: @user_id),
        build(:pageview)
      ])

      conn = get(conn, "/api/stats/#{site.domain}/top-stats?period=day")

      res = json_response(conn, 200)

      assert %{"name" => "Bounce rate", "value" => 50, "graph_metric" => "bounce_rate"} in res[
               "top_stats"
             ]
    end

    test "calculates average visit duration", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          timestamp: ~N[2021-01-01 00:15:00]
        )
      ])

      conn = get(conn, "/api/stats/#{site.domain}/top-stats?period=day&date=2021-01-01")

      res = json_response(conn, 200)

      assert %{"name" => "Visit duration", "value" => 450, "graph_metric" => "visit_duration"} in res[
               "top_stats"
             ]
    end

    test "calculates time on page instead when filtered for page", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/pageA",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/pageB",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          pathname: "/pageA",
          timestamp: ~N[2021-01-01 00:15:00]
        )
      ])

      filters = Jason.encode!([[:is, "event:page", ["/pageA"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=day&date=2021-01-01&filters=#{filters}"
        )

      res = json_response(conn, 200)

      assert %{"name" => "Time on page", "value" => 900, "graph_metric" => "time_on_page"} in res[
               "top_stats"
             ]
    end

    test "calculates time on page when filtered for multiple pages", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          pathname: "/pageA",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/pageB",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          pathname: "/pageC",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:16:00]
        ),
        build(:pageview,
          pathname: "/pageA",
          timestamp: ~N[2021-01-01 00:15:00]
        )
      ])

      filters = Jason.encode!([[:is, "event:page", ["/pageA", "/pageB"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=day&date=2021-01-01&filters=#{filters}"
        )

      res = json_response(conn, 200)

      assert %{"name" => "Time on page", "value" => 480, "graph_metric" => "time_on_page"} in res[
               "top_stats"
             ]
    end

    test "calculates time on page when filtered for multiple negated pages", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          pathname: "/pageA",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/pageB",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          pathname: "/pageC",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:16:00]
        ),
        build(:pageview,
          pathname: "/pageA",
          timestamp: ~N[2021-01-01 00:15:00]
        )
      ])

      filters = Jason.encode!([["is_not", "event:page", ["/pageA", "/pageC"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=day&date=2021-01-01&filters=#{filters}"
        )

      res = json_response(conn, 200)

      assert %{"name" => "Time on page", "value" => 60, "graph_metric" => "time_on_page"} in res[
               "top_stats"
             ]
    end

    test "calculates time on page when filtered for multiple contains pages", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          pathname: "/blog/post-1",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/about",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          pathname: "/articles/post-1",
          user_id: 321,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          pathname: "/",
          user_id: 321,
          timestamp: ~N[2021-01-01 00:16:00]
        )
      ])

      filters = Jason.encode!([[:contains, "event:page", ["/blog/", "/articles/"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=day&date=2021-01-01&filters=#{filters}"
        )

      res = json_response(conn, 200)

      assert %{"name" => "Time on page", "value" => 480, "graph_metric" => "time_on_page"} in res[
               "top_stats"
             ]
    end

    test "calculates time on page when filtered for multiple negated contains pages", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          pathname: "/blog/post-1",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/about",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:10:00]
        ),
        build(:pageview,
          pathname: "/",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/articles/post-1",
          timestamp: ~N[2021-01-01 00:10:00]
        )
      ])

      filters = Jason.encode!([["contains_not", "event:page", ["/blog/", "/articles/"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=day&date=2021-01-01&filters=#{filters}"
        )

      res = json_response(conn, 200)

      assert %{"name" => "Time on page", "value" => 600, "graph_metric" => "time_on_page"} in res[
               "top_stats"
             ]
    end

    test "doesn't calculate time on page with only single page visits", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/", user_id: @user_id, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, pathname: "/", user_id: @user_id, timestamp: ~N[2021-01-01 00:10:00])
      ])

      filters = Jason.encode!([[:is, "event:page", ["/"]]])
      path = "/api/stats/#{site.domain}/top-stats?period=day&date=2021-01-01&filters=#{filters}"

      assert %{"name" => "Time on page", "value" => 0, "graph_metric" => "time_on_page"} ==
               conn
               |> get(path)
               |> json_response(200)
               |> Map.fetch!("top_stats")
               |> Enum.find(&(&1["name"] == "Time on page"))
    end

    test "bounce_rate is 0 when the page in filter was never a landing page", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, pathname: "/A", user_id: @user_id, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, pathname: "/", user_id: @user_id, timestamp: ~N[2021-01-01 00:10:00])
      ])

      filters = Jason.encode!([[:is, "event:page", ["/"]]])
      path = "/api/stats/#{site.domain}/top-stats?period=day&date=2021-01-01&filters=#{filters}"

      assert %{"name" => "Bounce rate", "value" => 0, "graph_metric" => "bounce_rate"} ==
               conn
               |> get(path)
               |> json_response(200)
               |> Map.fetch!("top_stats")
               |> Enum.find(&(&1["name"] == "Bounce rate"))
    end

    test "time_on_page is 0 when it can't be calculated", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/")
      ])

      filters = Jason.encode!([[:is, "event:page", ["/"]]])
      path = "/api/stats/#{site.domain}/top-stats?&filters=#{filters}"

      assert %{"name" => "Time on page", "value" => 0, "graph_metric" => "time_on_page"} ==
               conn
               |> get(path)
               |> json_response(200)
               |> Map.fetch!("top_stats")
               |> Enum.find(&(&1["name"] == "Time on page"))
    end

    test "ignores page refresh when calculating time on page", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:00:00], pathname: "/"),
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:01:00], pathname: "/"),
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:02:00], pathname: "/"),
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:03:00], pathname: "/exit")
      ])

      filters = Jason.encode!([[:is, "event:page", ["/"]]])
      path = "/api/stats/#{site.domain}/top-stats?period=day&date=2021-01-01&filters=#{filters}"

      assert %{
               "name" => "Time on page",
               "value" => _three_minutes = 180,
               "graph_metric" => "time_on_page"
             } ==
               conn
               |> get(path)
               |> json_response(200)
               |> Map.fetch!("top_stats")
               |> Enum.find(&(&1["name"] == "Time on page"))
    end

    test "averages time on page over unique transitions across sessions", %{
      conn: conn,
      site: site
    } do
      # ┌─p──┬─p2─┬─minus(t2, t)─┬──s─┐
      # │ /a │ /b │          100 │ s1 │
      # │ /a │ /d │          100 │ s2 ��� <- these two get treated
      # │ /a │ /d │            0 │ s2 │ <- as single page transition
      # └────┴────┴──────────────┴────┘
      # so that time_on_page(a)=(100+100)/uniq(transition)=200/2=100

      s1 = @user_id
      s2 = @user_id + 1

      now = ~N[2021-01-01 00:00:00]
      later = fn seconds -> NaiveDateTime.add(now, seconds) end

      populate_stats(site, [
        build(:pageview, user_id: s1, timestamp: now, pathname: "/a"),
        build(:pageview, user_id: s1, timestamp: later.(100), pathname: "/b"),
        build(:pageview, user_id: s2, timestamp: now, pathname: "/a"),
        build(:pageview, user_id: s2, timestamp: later.(100), pathname: "/d"),
        build(:pageview, user_id: s2, timestamp: later.(100), pathname: "/a"),
        build(:pageview, user_id: s2, timestamp: later.(100), pathname: "/d")
      ])

      filters = Jason.encode!([[:is, "event:page", ["/a"]]])
      path = "/api/stats/#{site.domain}/top-stats?period=day&date=2021-01-01&filters=#{filters}"

      assert %{"name" => "Time on page", "value" => 100, "graph_metric" => "time_on_page"} ==
               conn
               |> get(path)
               |> json_response(200)
               |> Map.fetch!("top_stats")
               |> Enum.find(&(&1["name"] == "Time on page"))
    end
  end

  describe "GET /api/stats/top-stats - with imported data" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "returns divisible metrics as 0 when no stats exist", %{
      site: site,
      conn: conn
    } do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=day&date=2021-01-01&with_imported=true"
        )

      res = json_response(conn, 200)

      assert %{"name" => "Bounce rate", "value" => 0, "graph_metric" => "bounce_rate"} in res[
               "top_stats"
             ]

      assert %{"name" => "Views per visit", "value" => 0.0, "graph_metric" => "views_per_visit"} in res[
               "top_stats"
             ]

      assert %{"name" => "Visit duration", "value" => 0, "graph_metric" => "visit_duration"} in res[
               "top_stats"
             ]
    end

    test "merges imported data into all top stat metrics", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:imported_visitors, date: ~D[2021-01-01])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=day&date=2021-01-01&with_imported=true"
        )

      res = json_response(conn, 200)

      assert res["top_stats"] == [
               %{"name" => "Unique visitors", "value" => 3, "graph_metric" => "visitors"},
               %{"name" => "Total visits", "value" => 3, "graph_metric" => "visits"},
               %{"name" => "Total pageviews", "value" => 4, "graph_metric" => "pageviews"},
               %{
                 "name" => "Views per visit",
                 "value" => 1.33,
                 "graph_metric" => "views_per_visit"
               },
               %{"name" => "Bounce rate", "value" => 33, "graph_metric" => "bounce_rate"},
               %{"name" => "Visit duration", "value" => 303, "graph_metric" => "visit_duration"}
             ]
    end

    test ":member filter on country", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          country_code: "EE",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          country_code: "EE",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:imported_locations,
          country: "EE",
          date: ~D[2021-01-01],
          visitors: 1,
          visits: 3,
          pageviews: 34,
          bounces: 0,
          visit_duration: 420
        ),
        build(:imported_locations,
          country: "FR",
          date: ~D[2021-01-01],
          visitors: 3,
          visits: 7,
          pageviews: 65,
          bounces: 1,
          visit_duration: 300
        ),
        build(:imported_locations, country: "US", date: ~D[2021-01-01], visitors: 999)
      ])

      filters = Jason.encode!([[:is, "visit:country", ["EE", "FR"]]])
      q = "?period=day&date=2021-01-01&with_imported=true&filters=#{filters}"

      conn = get(conn, "/api/stats/#{site.domain}/top-stats#{q}")

      res = json_response(conn, 200)

      assert res["top_stats"] == [
               %{"name" => "Unique visitors", "value" => 5, "graph_metric" => "visitors"},
               %{"name" => "Total visits", "value" => 11, "graph_metric" => "visits"},
               %{"name" => "Total pageviews", "value" => 101, "graph_metric" => "pageviews"},
               %{
                 "name" => "Views per visit",
                 "value" => 9.18,
                 "graph_metric" => "views_per_visit"
               },
               %{"name" => "Bounce rate", "value" => 9, "graph_metric" => "bounce_rate"},
               %{"name" => "Visit duration", "value" => 71, "graph_metric" => "visit_duration"}
             ]
    end

    test ":is filter on page returns only visitors, visits, pageviews and scroll_depth", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:imported_pages,
          page: "/",
          date: ~D[2021-01-01],
          visitors: 1,
          visits: 3,
          pageviews: 34
        ),
        build(:imported_pages, page: "/ignored", date: ~D[2021-01-01], visitors: 999)
      ])

      filters = Jason.encode!([[:is, "event:page", ["/"]]])
      q = "?period=day&date=2021-01-01&with_imported=true&filters=#{filters}"

      conn = get(conn, "/api/stats/#{site.domain}/top-stats#{q}")

      res = json_response(conn, 200)

      assert res["top_stats"] == [
               %{"name" => "Unique visitors", "value" => 2, "graph_metric" => "visitors"},
               %{"name" => "Total visits", "value" => 4, "graph_metric" => "visits"},
               %{"name" => "Total pageviews", "value" => 36, "graph_metric" => "pageviews"},
               %{"name" => "Scroll depth", "value" => nil, "graph_metric" => "scroll_depth"}
             ]
    end
  end

  describe "GET /api/stats/top-stats - with_imported_switch info" do
    setup [:create_user, :log_in, :create_site]

    setup context do
      insert(:site_import,
        site: context.site,
        start_date: ~D[2021-03-01],
        end_date: ~D[2021-03-31]
      )

      context
    end

    test "visible is false in realtime", %{conn: conn, site: site} do
      q = "?period=realtime"
      conn = get(conn, "/api/stats/#{site.domain}/top-stats#{q}")

      res = json_response(conn, 200)

      assert res["with_imported_switch"] == %{
               "visible" => false,
               "togglable" => false,
               "tooltip_msg" => nil
             }
    end

    test "when the site has no imported data", %{conn: conn, site: site} do
      Plausible.Imported.delete_imports_for_site(site)

      q = "?period=day&date=2021-01-01&with_imported=true"
      conn = get(conn, "/api/stats/#{site.domain}/top-stats#{q}")

      res = json_response(conn, 200)

      assert res["with_imported_switch"] == %{
               "visible" => false,
               "togglable" => false,
               "tooltip_msg" => nil
             }
    end

    test "when imported data does not exist in the queried period", %{conn: conn, site: site} do
      q = "?period=day&date=2022-05-05&with_imported=true"
      conn = get(conn, "/api/stats/#{site.domain}/top-stats#{q}")

      res = json_response(conn, 200)

      assert res["with_imported_switch"] == %{
               "visible" => false,
               "togglable" => false,
               "tooltip_msg" => nil
             }
    end

    test "when imported data is requested, in range, and can be included", %{
      conn: conn,
      site: site
    } do
      q = "?period=day&date=2021-03-15&with_imported=true"
      conn = get(conn, "/api/stats/#{site.domain}/top-stats#{q}")

      res = json_response(conn, 200)

      assert res["with_imported_switch"] == %{
               "visible" => true,
               "togglable" => true,
               "tooltip_msg" => "Click to exclude imported data"
             }
    end

    test "when imported data is not requested, but in range and can be included", %{
      conn: conn,
      site: site
    } do
      q = "?period=day&date=2021-03-15&with_imported=false"
      conn = get(conn, "/api/stats/#{site.domain}/top-stats#{q}")

      res = json_response(conn, 200)

      assert res["with_imported_switch"] == %{
               "visible" => true,
               "togglable" => true,
               "tooltip_msg" => "Click to include imported data"
             }
    end

    test "when imported data is requested and in range, but cannot be included", %{
      conn: conn,
      site: site
    } do
      insert(:goal, site: site, event_name: "Signup")

      filters =
        Jason.encode!([[:is, "event:goal", ["Signup"]], [:is, "event:page", ["/register"]]])

      q = "?period=day&date=2021-03-15&with_imported=true&filters=#{filters}"

      conn = get(conn, "/api/stats/#{site.domain}/top-stats#{q}")

      res = json_response(conn, 200)

      assert res["with_imported_switch"] == %{
               "visible" => true,
               "togglable" => false,
               "tooltip_msg" => "Imported data cannot be included"
             }
    end

    test "when imported data is requested and in comparison range", %{conn: conn, site: site} do
      q = "?period=day&date=2022-03-15&with_imported=true&comparison=year_over_year"

      conn = get(conn, "/api/stats/#{site.domain}/top-stats#{q}")

      res = json_response(conn, 200)

      assert res["with_imported_switch"] == %{
               "visible" => true,
               "togglable" => true,
               "tooltip_msg" => "Click to exclude imported data"
             }
    end

    test "when imported data is not requested and in comparison range", %{conn: conn, site: site} do
      q = "?period=day&date=2022-03-15&with_imported=false&comparison=year_over_year"

      conn = get(conn, "/api/stats/#{site.domain}/top-stats#{q}")

      res = json_response(conn, 200)

      assert res["with_imported_switch"] == %{
               "visible" => true,
               "togglable" => true,
               "tooltip_msg" => "Click to include imported data"
             }
    end
  end

  describe "GET /api/stats/top-stats - realtime" do
    setup [:create_user, :log_in, :create_site]

    test "shows current visitors (last 5 minutes)", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: relative_time(minutes: -10)),
        build(:pageview, timestamp: relative_time(minutes: -4)),
        build(:pageview, timestamp: relative_time(minutes: -1))
      ])

      conn = get(conn, "/api/stats/#{site.domain}/top-stats?period=realtime")

      res = json_response(conn, 200)

      assert %{"name" => "Current visitors", "value" => 2, "graph_metric" => "current_visitors"} in res[
               "top_stats"
             ]
    end

    test "shows unique visitors (last 30 minutes)", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: relative_time(minutes: -45)),
        build(:pageview, timestamp: relative_time(minutes: -25)),
        build(:pageview, timestamp: relative_time(minutes: -1))
      ])

      conn = get(conn, "/api/stats/#{site.domain}/top-stats?period=realtime")

      res = json_response(conn, 200)

      assert %{
               "name" => "Unique visitors (last 30 min)",
               "value" => 2,
               "graph_metric" => "visitors"
             } in res["top_stats"]
    end

    test "shows pageviews (last 30 minutes)", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id, timestamp: relative_time(minutes: -45)),
        build(:pageview, user_id: @user_id, timestamp: relative_time(minutes: -25)),
        build(:pageview, user_id: @user_id, timestamp: relative_time(minutes: -20)),
        build(:pageview, timestamp: relative_time(minutes: -1))
      ])

      conn = get(conn, "/api/stats/#{site.domain}/top-stats?period=realtime")

      res = json_response(conn, 200)

      assert %{"name" => "Pageviews (last 30 min)", "value" => 3, "graph_metric" => "pageviews"} in res[
               "top_stats"
             ]
    end

    test "shows current visitors (last 5 min) with goal filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: relative_time(minutes: -10)),
        build(:pageview, timestamp: relative_time(minutes: -3)),
        build(:event, name: "Signup", timestamp: relative_time(minutes: -2)),
        build(:event, name: "Signup", timestamp: relative_time(minutes: -1))
      ])

      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      conn = get(conn, "/api/stats/#{site.domain}/top-stats?period=realtime&filters=#{filters}")

      res = json_response(conn, 200)

      assert %{"name" => "Current visitors", "value" => 3, "graph_metric" => "current_visitors"} in res[
               "top_stats"
             ]
    end

    test "shows unique/total conversions (last 30 min) with goal filter", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event, name: "Signup", timestamp: relative_time(minutes: -45)),
        build(:event, name: "Signup", timestamp: relative_time(minutes: -25)),
        build(:event, name: "Signup", user_id: @user_id, timestamp: relative_time(minutes: -22)),
        build(:event, name: "Signup", user_id: @user_id, timestamp: relative_time(minutes: -21)),
        build(:event, name: "Signup", user_id: @user_id, timestamp: relative_time(minutes: -20))
      ])

      insert(:goal, site: site, event_name: "Signup")
      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      conn = get(conn, "/api/stats/#{site.domain}/top-stats?period=realtime&filters=#{filters}")

      res = json_response(conn, 200)

      assert %{
               "name" => "Unique conversions (last 30 min)",
               "value" => 2,
               "graph_metric" => "visitors"
             } in res["top_stats"]

      assert %{
               "name" => "Total conversions (last 30 min)",
               "value" => 4,
               "graph_metric" => "events"
             } in res["top_stats"]
    end
  end

  describe "GET /api/stats/top-stats - filters" do
    setup [:create_user, :log_in, :create_site]

    test "returns graph_metric key for top stats with a page filter", %{
      conn: conn,
      site: site
    } do
      filters = Jason.encode!([[:is, "event:page", ["/A"]]])

      [visitors, visits, pageviews, bounce_rate, time_on_page, scroll_depth] =
        conn
        |> get("/api/stats/#{site.domain}/top-stats?filters=#{filters}")
        |> json_response(200)
        |> Map.get("top_stats")

      assert %{"graph_metric" => "visitors"} = visitors
      assert %{"graph_metric" => "visits"} = visits
      assert %{"graph_metric" => "pageviews"} = pageviews
      assert %{"graph_metric" => "bounce_rate"} = bounce_rate
      assert %{"graph_metric" => "time_on_page"} = time_on_page
      assert %{"graph_metric" => "scroll_depth"} = scroll_depth
    end

    test "returns graph_metric key for top stats with a goal filter", %{
      conn: conn,
      site: site
    } do
      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      [unique_visitors, unique_conversions, total_conversions, cr] =
        conn
        |> get("/api/stats/#{site.domain}/top-stats?filters=#{filters}")
        |> json_response(200)
        |> Map.get("top_stats")

      assert %{"graph_metric" => "total_visitors"} = unique_visitors
      assert %{"graph_metric" => "visitors"} = unique_conversions
      assert %{"graph_metric" => "events"} = total_conversions
      assert %{"graph_metric" => "conversion_rate"} = cr
    end

    test "returns graph_metric key for top stats with a goal filter in realtime mode",
         %{conn: conn, site: site} do
      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      [current_visitors, unique_conversions, total_conversions] =
        conn
        |> get("/api/stats/#{site.domain}/top-stats?period=realtime&filters=#{filters}")
        |> json_response(200)
        |> Map.get("top_stats")

      assert %{"graph_metric" => "current_visitors"} = current_visitors
      assert %{"graph_metric" => "visitors"} = unique_conversions
      assert %{"graph_metric" => "events"} = total_conversions
    end

    test "returns only visitors from a country based on alpha2 code", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, country_code: "US"),
        build(:pageview, country_code: "US"),
        build(:pageview, country_code: "EE")
      ])

      filters = Jason.encode!([[:is, "visit:country", ["US"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=month&filters=#{filters}"
        )

      res = json_response(conn, 200)

      assert %{"name" => "Unique visitors", "value" => 2, "graph_metric" => "visitors"} in res[
               "top_stats"
             ]
    end

    test "returns scroll_depth with a page filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 123, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageleave, user_id: 123, timestamp: ~N[2021-01-01 00:00:10], scroll_depth: 40),
        build(:pageview, user_id: 123, timestamp: ~N[2021-01-01 00:00:10]),
        build(:pageleave, user_id: 123, timestamp: ~N[2021-01-01 00:00:20], scroll_depth: 60),
        build(:pageview, user_id: 456, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageleave, user_id: 456, timestamp: ~N[2021-01-01 00:00:10], scroll_depth: 80)
      ])

      filters = Jason.encode!([[:is, "event:page", ["/"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=day&date=2021-01-01&filters=#{filters}"
        )

      res = json_response(conn, 200)

      assert %{"name" => "Scroll depth", "value" => 70, "graph_metric" => "scroll_depth"} in res[
               "top_stats"
             ]
    end

    test "returns scroll_depth with a page filter with imported data", %{conn: conn, site: site} do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:pageview, user_id: 123, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageleave, user_id: 123, timestamp: ~N[2021-01-01 00:00:10], scroll_depth: 40),
        build(:pageview, user_id: 123, timestamp: ~N[2021-01-01 00:00:10]),
        build(:pageleave, user_id: 123, timestamp: ~N[2021-01-01 00:00:20], scroll_depth: 60),
        build(:pageview, user_id: 456, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageleave, user_id: 456, timestamp: ~N[2021-01-01 00:00:10], scroll_depth: 80),
        build(:imported_pages,
          page: "/",
          date: ~D[2021-01-01],
          visitors: 8,
          scroll_depth: 410,
          pageleave_visitors: 8
        ),
        build(:imported_pages, page: "/", date: ~D[2021-01-02], visitors: 100, scroll_depth: nil)
      ])

      filters = Jason.encode!([[:is, "event:page", ["/"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=7d&date=2021-01-07&filters=#{filters}&with_imported=true"
        )

      res = json_response(conn, 200)

      assert %{"name" => "Scroll depth", "value" => 55, "graph_metric" => "scroll_depth"} in res[
               "top_stats"
             ]
    end

    test "contains filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/some-blog-post"),
        build(:pageview, pathname: "/blog/post1"),
        build(:pageview, pathname: "/another/post")
      ])

      filters = Jason.encode!([[:contains, "event:page", ["blog"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=month&filters=#{filters}"
        )

      res = json_response(conn, 200)

      assert %{"name" => "Unique visitors", "value" => 2, "graph_metric" => "visitors"} in res[
               "top_stats"
             ]
    end

    test "returns only visitors with specific screen size", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, screen_size: "Desktop"),
        build(:pageview, screen_size: "Desktop"),
        build(:pageview, screen_size: "Mobile")
      ])

      filters = Jason.encode!([[:is, "visit:screen", ["Desktop"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=month&filters=#{filters}"
        )

      res = json_response(conn, 200)

      assert %{"name" => "Unique visitors", "value" => 2, "graph_metric" => "visitors"} in res[
               "top_stats"
             ]
    end

    test "returns only visitors with specific screen size for a given hostname", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, screen_size: "Desktop", hostname: "blog.example.com"),
        build(:pageview, screen_size: "Desktop", hostname: "example.com", user_id: @user_id),
        build(:pageview, screen_size: "Desktop", hostname: "blog.example.com", user_id: @user_id),
        build(:pageview,
          screen_size: "Desktop",
          hostname: "blog.example.com",
          user_id: @user_id + 1
        ),
        build(:pageview, screen_size: "Desktop", hostname: "example.com", user_id: @user_id + 1),
        build(:pageview, screen_size: "Mobile", hostname: "blog.example.com")
      ])

      filters =
        Jason.encode!([
          [:is, "visit:screen", ["Desktop"]],
          [:is, "event:hostname", ["blog.example.com"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=month&filters=#{filters}"
        )

      res =
        json_response(conn, 200)

      assert %{"name" => "Unique visitors", "value" => 3, "graph_metric" => "visitors"} in res[
               "top_stats"
             ]

      assert %{"name" => "Total visits", "value" => 3, "graph_metric" => "visits"} in res[
               "top_stats"
             ]
    end

    test "returns only visitors with specific browser", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, browser: "Chrome"),
        build(:pageview, browser: "Chrome"),
        build(:pageview, browser: "Safari")
      ])

      filters = Jason.encode!([[:is, "visit:browser", ["Chrome"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=month&filters=#{filters}"
        )

      res = json_response(conn, 200)

      assert %{"name" => "Unique visitors", "value" => 2, "graph_metric" => "visitors"} in res[
               "top_stats"
             ]
    end

    test "returns only visitors with specific operating system", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, operating_system: "Mac"),
        build(:pageview, operating_system: "Mac"),
        build(:pageview, operating_system: "Windows")
      ])

      filters = Jason.encode!([[:is, "visit:os", ["Mac"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=month&filters=#{filters}"
        )

      res = json_response(conn, 200)

      assert %{"name" => "Unique visitors", "value" => 2, "graph_metric" => "visitors"} in res[
               "top_stats"
             ]
    end

    test "returns number of visits from one specific referral source", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: @user_id,
          referrer_source: "Google",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          referrer_source: "Google",
          timestamp: ~N[2021-01-01 00:05:00]
        ),
        build(:pageview,
          user_id: @user_id,
          referrer_source: "Google",
          timestamp: ~N[2021-01-01 05:00:00]
        ),
        build(:pageview, timestamp: ~N[2021-01-01 00:10:00])
      ])

      filters = Jason.encode!([[:is, "visit:source", ["Google"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=day&date=2021-01-01&filters=#{filters}"
        )

      res = json_response(conn, 200)

      assert %{"name" => "Total visits", "value" => 2, "graph_metric" => "visits"} in res[
               "top_stats"
             ]
    end

    test "does not return the views_per_visit metric when a page filter is applied", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, pathname: "/")
      ])

      filters = Jason.encode!([[:is, "event:page", ["/"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=day&filters=#{filters}"
        )

      res = json_response(conn, 200)

      refute Enum.any?(res["top_stats"], fn
               %{"name" => "Views per visit"} -> true
               _ -> false
             end)
    end

    test "hostname exact filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/index", hostname: "example.com"),
        build(:pageview, pathname: "/index", hostname: "example.com", user_id: @user_id),
        build(:pageview, pathname: "/blog/post1", hostname: "blog.example.com", user_id: @user_id),
        build(:pageview, pathname: "/blog/post2", hostname: "blog.example.com")
      ])

      filters = Jason.encode!([[:is, "event:hostname", ["example.com"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=month&filters=#{filters}"
        )

      res = json_response(conn, 200)

      assert %{"name" => "Unique visitors", "value" => 2, "graph_metric" => "visitors"} in res[
               "top_stats"
             ]

      assert %{"name" => "Total pageviews", "value" => 2, "graph_metric" => "pageviews"} in res[
               "top_stats"
             ]
    end

    test "hostname contains filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/index", hostname: "example.com"),
        build(:pageview, pathname: "/index", hostname: "example.com", user_id: @user_id),
        build(:pageview, pathname: "/blog/post1", hostname: "blog.example.com", user_id: @user_id),
        build(:pageview, pathname: "/blog/post2", hostname: "blog.example.com", user_id: @user_id),
        build(:pageview, pathname: "/blog/post2", hostname: "blog.example.com"),
        build(:pageview, pathname: "/blog/post2", hostname: "about.example.com")
      ])

      filters = Jason.encode!([[:contains, "event:hostname", ["example.com"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=month&filters=#{filters}"
        )

      res =
        json_response(conn, 200)

      assert %{"name" => "Unique visitors", "value" => 4, "graph_metric" => "visitors"} in res[
               "top_stats"
             ]

      assert %{"name" => "Total pageviews", "value" => 6, "graph_metric" => "pageviews"} in res[
               "top_stats"
             ]
    end

    test "hostname contains subdomain filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/index", hostname: "example.com"),
        build(:pageview, pathname: "/index", hostname: "example.com", user_id: @user_id),
        build(:pageview, pathname: "/blog/post1", hostname: "blog.example.com", user_id: @user_id),
        build(:pageview, pathname: "/blog/post2", hostname: "blog.example.com", user_id: @user_id),
        build(:pageview, pathname: "/blog/post3", hostname: "blog.example.com"),
        build(:pageview,
          pathname: "/blog/post2",
          hostname: "blog.example.com",
          user_id: 100_002_378_237
        )
      ])

      filters = Jason.encode!([[:contains, "event:hostname", [".example.com"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=month&filters=#{filters}"
        )

      res = json_response(conn, 200)

      assert %{"name" => "Unique visitors", "value" => 3, "graph_metric" => "visitors"} in res[
               "top_stats"
             ]

      assert %{"name" => "Total pageviews", "value" => 4, "graph_metric" => "pageviews"} in res[
               "top_stats"
             ]
    end
  end

  describe "GET /api/stats/top-stats - filtered for goal" do
    setup [:create_user, :log_in, :create_site]

    test "returns total unique visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id),
        build(:pageview, user_id: @user_id),
        build(:pageview),
        build(:event, name: "Signup")
      ])

      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=day&filters=#{filters}"
        )

      res = json_response(conn, 200)

      assert %{"name" => "Unique visitors", "value" => 3, "graph_metric" => "total_visitors"} in res[
               "top_stats"
             ]
    end

    test "returns converted visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id),
        build(:pageview, user_id: @user_id),
        build(:pageview),
        build(:event, name: "Signup")
      ])

      insert(:goal, site: site, event_name: "Signup")
      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=month&filters=#{filters}"
        )

      res = json_response(conn, 200)

      assert %{"name" => "Unique conversions", "value" => 1, "graph_metric" => "visitors"} in res[
               "top_stats"
             ]
    end

    test "returns conversion rate", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id),
        build(:pageview, user_id: @user_id),
        build(:pageview),
        build(:event, name: "Signup")
      ])

      insert(:goal, site: site, event_name: "Signup")
      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=day&filters=#{filters}"
        )

      res = json_response(conn, 200)

      assert %{"name" => "Conversion rate", "value" => 33.3, "graph_metric" => "conversion_rate"} in res[
               "top_stats"
             ]
    end

    test "returns conversion rate without change when comparison mode disallowed", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, user_id: @user_id),
        build(:pageview, user_id: @user_id),
        build(:pageview),
        build(:event, name: "Signup")
      ])

      insert(:goal, site: site, event_name: "Signup")
      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=all&filters=#{filters}&comparison_mode=year_over_year"
        )

      res = json_response(conn, 200)

      assert %{"name" => "Conversion rate", "value" => 33.3, "graph_metric" => "conversion_rate"} in res[
               "top_stats"
             ]
    end

    @tag :ee_only
    test "returns average and total when filtering by a revenue goal", %{conn: conn, site: site} do
      insert(:goal,
        site: site,
        event_name: "Payment",
        currency: "USD",
        display_name: "PaymentUSD"
      )

      insert(:goal,
        site: site,
        event_name: "AddToCart",
        currency: "EUR",
        display_name: "AddToCartEUR"
      )

      populate_stats(site, [
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new(13_29),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new(19_90),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "AddToCart",
          revenue_reporting_amount: Decimal.new(10_31),
          revenue_reporting_currency: "EUR"
        ),
        build(:event,
          name: "AddToCart",
          revenue_reporting_amount: Decimal.new(20_00),
          revenue_reporting_currency: "EUR"
        )
      ])

      filters = Jason.encode!([[:is, "event:goal", ["PaymentUSD"]]])
      conn = get(conn, "/api/stats/#{site.domain}/top-stats?period=all&filters=#{filters}")
      assert %{"top_stats" => top_stats} = json_response(conn, 200)

      assert %{
               "name" => "Average revenue",
               "value" => %{
                 "long" => "$1,659.50",
                 "short" => "$1.7K",
                 "value" => 1659.5,
                 "currency" => "USD"
               },
               "graph_metric" => "average_revenue"
             } in top_stats

      assert %{
               "name" => "Total revenue",
               "value" => %{
                 "long" => "$3,319.00",
                 "short" => "$3.3K",
                 "value" => 3319.0,
                 "currency" => "USD"
               },
               "graph_metric" => "total_revenue"
             } in top_stats
    end

    @tag :ee_only
    test "returns average and total when filtering by many revenue goals with same currency", %{
      conn: conn,
      site: site
    } do
      insert(:goal, site: site, event_name: "Payment", currency: "USD")
      insert(:goal, site: site, event_name: "Payment2", currency: "USD")
      insert(:goal, site: site, event_name: "AddToCart", currency: "EUR")

      populate_stats(site, [
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new(13_29),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new(19_90),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment2",
          revenue_reporting_amount: Decimal.new(13_29),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment2",
          revenue_reporting_amount: Decimal.new(19_90),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "AddToCart",
          revenue_reporting_amount: Decimal.new(10_31),
          revenue_reporting_currency: "EUR"
        ),
        build(:event,
          name: "AddToCart",
          revenue_reporting_amount: Decimal.new(20_00),
          revenue_reporting_currency: "EUR"
        )
      ])

      filters = Jason.encode!([[:is, "event:goal", ["Payment", "Payment2"]]])
      conn = get(conn, "/api/stats/#{site.domain}/top-stats?period=all&filters=#{filters}")
      assert %{"top_stats" => top_stats} = json_response(conn, 200)

      assert %{
               "name" => "Average revenue",
               "value" => %{
                 "long" => "$1,659.50",
                 "short" => "$1.7K",
                 "value" => 1659.5,
                 "currency" => "USD"
               },
               "graph_metric" => "average_revenue"
             } in top_stats

      assert %{
               "name" => "Total revenue",
               "value" => %{
                 "long" => "$6,638.00",
                 "short" => "$6.6K",
                 "value" => 6638.0,
                 "currency" => "USD"
               },
               "graph_metric" => "total_revenue"
             } in top_stats
    end

    @tag :ee_only
    test "does not return average and total when filtering by many revenue goals with different currencies",
         %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Payment", currency: "USD")
      insert(:goal, site: site, event_name: "AddToCart", currency: "EUR")

      populate_stats(site, [
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new(13_29),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new(19_90),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "AddToCart",
          revenue_reporting_amount: Decimal.new(10_31),
          revenue_reporting_currency: "EUR"
        ),
        build(:event,
          name: "AddToCart",
          revenue_reporting_amount: Decimal.new(20_00),
          revenue_reporting_currency: "EUR"
        )
      ])

      filters = Jason.encode!([[:is, "event:goal", ["Payment", "AddToCart"]]])
      conn = get(conn, "/api/stats/#{site.domain}/top-stats?period=all&filters=#{filters}")
      assert %{"top_stats" => top_stats} = json_response(conn, 200)

      metrics = Enum.map(top_stats, & &1["name"])
      refute "Average revenue" in metrics
      refute "Total revenue" in metrics
    end

    @tag :ee_only
    test "returns average and total revenue when filtering by many goals some which don't have currencies",
         %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Payment", currency: "USD")
      insert(:goal, site: site, event_name: "Signup")

      populate_stats(site, [
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new(1_000),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new(1_000),
          revenue_reporting_currency: "USD"
        ),
        build(:event, name: "Signup"),
        build(:event, name: "Signup")
      ])

      filters = Jason.encode!([[:is, "event:goal", ["Payment", "Signup"]]])
      conn = get(conn, "/api/stats/#{site.domain}/top-stats?period=all&filters=#{filters}")
      assert %{"top_stats" => top_stats} = json_response(conn, 200)

      assert %{
               "name" => "Average revenue",
               "value" => %{
                 "long" => "$1,000.00",
                 "short" => "$1.0K",
                 "value" => 1000.0,
                 "currency" => "USD"
               },
               "graph_metric" => "average_revenue"
             } in top_stats

      assert %{
               "name" => "Total revenue",
               "value" => %{
                 "long" => "$2,000.00",
                 "short" => "$2.0K",
                 "value" => 2000.0,
                 "currency" => "USD"
               },
               "graph_metric" => "total_revenue"
             } in top_stats
    end

    @tag :ee_only
    test "returns average and total revenue when no conversions",
         %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Payment", currency: "USD")

      filters = Jason.encode!([[:is, "event:goal", ["Payment", "Signup"]]])
      conn = get(conn, "/api/stats/#{site.domain}/top-stats?period=all&filters=#{filters}")
      assert %{"top_stats" => top_stats} = json_response(conn, 200)

      assert %{
               "name" => "Average revenue",
               "value" => %{
                 "long" => "$0.00",
                 "short" => "$0.0",
                 "value" => 0.0,
                 "currency" => "USD"
               },
               "graph_metric" => "average_revenue"
             } in top_stats

      assert %{
               "name" => "Total revenue",
               "value" => %{
                 "long" => "$0.00",
                 "short" => "$0.0",
                 "value" => 0.0,
                 "currency" => "USD"
               },
               "graph_metric" => "total_revenue"
             } in top_stats
    end

    @tag :ee_only
    test "does not return average and total revenue when filtering non-currency goal",
         %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Payment", display_name: "PaymentWithoutCurrency")

      populate_stats(site, [
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new(1_000),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new(1_000),
          revenue_reporting_currency: "USD"
        )
      ])

      filters = Jason.encode!([[:is, "event:goal", ["PaymentWithoutCurrency"]]])
      conn = get(conn, "/api/stats/#{site.domain}/top-stats?period=all&filters=#{filters}")
      assert %{"top_stats" => top_stats} = json_response(conn, 200)

      metrics = Enum.map(top_stats, & &1["name"])
      refute "Average revenue" in metrics
      refute "Total revenue" in metrics
    end

    test "does not return average and total when site owner is on a growth plan",
         %{conn: conn, site: site, user: user} do
      subscribe_to_growth_plan(user)
      insert(:goal, site: site, event_name: "Payment", currency: "USD")

      populate_stats(site, [
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new(13_29),
          revenue_reporting_currency: "USD"
        )
      ])

      filters = Jason.encode!([[:is, "event:goal", ["Payment"]]])
      conn = get(conn, "/api/stats/#{site.domain}/top-stats?period=all&filters=#{filters}")
      assert %{"top_stats" => top_stats} = json_response(conn, 200)

      metrics = Enum.map(top_stats, & &1["name"])
      refute "Average revenue" in metrics
      refute "Total revenue" in metrics
    end
  end

  describe "GET /api/stats/top-stats - with comparisons" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "does not return comparisons by default", %{site: site, conn: conn} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-12-31 00:00:00]),
        build(:pageview, timestamp: ~N[2020-12-31 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, timestamp: ~N[2021-01-01 10:00:00])
      ])

      conn = get(conn, "/api/stats/#{site.domain}/top-stats?period=day&date=2021-01-01")

      res = json_response(conn, 200)

      assert %{"name" => "Total visits", "value" => 3, "graph_metric" => "visits"} in res[
               "top_stats"
             ]
    end

    test "returns comparison data when mode is custom", %{site: site, conn: conn} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2020-01-05 00:00:00]),
        build(:pageview, timestamp: ~N[2020-01-20 00:00:00]),
        build(:pageview, timestamp: ~N[2020-12-31 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, timestamp: ~N[2021-01-01 10:00:00])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=day&date=2021-01-01&comparison=custom&compare_from=2020-01-01&compare_to=2020-01-20"
        )

      res = json_response(conn, 200)

      assert %{
               "change" => 0,
               "comparison_value" => 3,
               "name" => "Total visits",
               "value" => 3,
               "graph_metric" => "visits"
             } in res[
               "top_stats"
             ]
    end

    test "returns source query and comparison query date range", %{site: site, conn: conn} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2020-01-05 00:00:00]),
        build(:pageview, timestamp: ~N[2020-01-20 00:00:00]),
        build(:pageview, timestamp: ~N[2020-12-31 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, timestamp: ~N[2021-01-01 10:00:00])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=month&date=2021-01-01&comparison=previous_period"
        )

      assert %{
               "comparing_from" => "2020-12-01",
               "comparing_to" => "2020-12-31",
               "from" => "2021-01-01",
               "to" => "2021-01-31"
             } = json_response(conn, 200)
    end

    test "compares native and imported data", %{site: site, conn: conn} do
      populate_stats(site, [
        build(:imported_visitors, date: ~D[2020-01-02]),
        build(:imported_visitors, date: ~D[2020-01-02]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=month&date=2021-01-01&with_imported=true&comparison=year_over_year"
        )

      assert %{"top_stats" => top_stats, "includes_imported" => true} = json_response(conn, 200)

      assert %{
               "change" => 100,
               "comparison_value" => 2,
               "name" => "Total visits",
               "value" => 4,
               "graph_metric" => "visits"
             } in top_stats
    end

    test "does not compare imported data when with_imported is set to false", %{
      site: site,
      conn: conn
    } do
      populate_stats(site, [
        build(:imported_visitors, date: ~D[2020-01-02]),
        build(:imported_visitors, date: ~D[2020-01-02]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=month&date=2021-01-01&with_imported=false&comparison=year_over_year"
        )

      assert %{"top_stats" => top_stats, "includes_imported" => false} = json_response(conn, 200)

      assert %{
               "change" => 100,
               "comparison_value" => 0,
               "name" => "Total visits",
               "value" => 4,
               "graph_metric" => "visits"
             } in top_stats
    end

    test "compares conversion rates", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id, timestamp: ~N[2023-01-03T00:00:00]),
        build(:pageview, user_id: @user_id, timestamp: ~N[2023-01-03T00:00:00]),
        build(:pageview, timestamp: ~N[2023-01-03T00:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2023-01-03T00:00:00]),
        build(:pageview, user_id: @user_id, timestamp: ~N[2023-01-02T00:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2023-01-02T00:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2023-01-02T00:00:00])
      ])

      insert(:goal, site: site, event_name: "Signup")
      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=day&date=2023-01-03&comparison=previous_period&filters=#{filters}"
        )

      res = json_response(conn, 200)

      assert %{
               "change" => -33.4,
               "comparison_value" => 66.7,
               "name" => "Conversion rate",
               "value" => 33.3,
               "graph_metric" => "conversion_rate"
             } in res["top_stats"]
    end
  end
end
