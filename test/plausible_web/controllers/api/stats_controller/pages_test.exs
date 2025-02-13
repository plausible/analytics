defmodule PlausibleWeb.Api.StatsController.PagesTest do
  use PlausibleWeb.ConnCase
  use Plausible.Teams.Test

  @user_id Enum.random(1000..9999)

  describe "GET /api/stats/:domain/pages" do
    setup [
      :create_user,
      :log_in,
      :create_site,
      :create_legacy_site_import,
      :set_scroll_depth_visible_at
    ]

    test "returns top pages by visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/register"),
        build(:pageview, pathname: "/register"),
        build(:pageview, pathname: "/contact")
      ])

      conn = get(conn, "/api/stats/#{site.domain}/pages?period=day")

      assert json_response(conn, 200)["results"] == [
               %{"visitors" => 3, "name" => "/"},
               %{"visitors" => 2, "name" => "/register"},
               %{"visitors" => 1, "name" => "/contact"}
             ]
    end

    test "returns top pages by visitors by hostname", %{conn: conn1, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/", hostname: "a.example.com"),
        build(:pageview, pathname: "/", hostname: "b.example.com"),
        build(:pageview, pathname: "/", hostname: "d.example.com"),
        build(:pageview, pathname: "/landing", hostname: "x.example.com", user_id: 123),
        build(:pageview, pathname: "/register", hostname: "d.example.com", user_id: 123),
        build(:pageview, pathname: "/register", hostname: "d.example.com", user_id: 123),
        build(:pageview, pathname: "/register", hostname: "d.example.com"),
        build(:pageview, pathname: "/contact", hostname: "e.example.com")
      ])

      filters = Jason.encode!([[:contains, "event:hostname", [".example.com"]]])
      conn = get(conn1, "/api/stats/#{site.domain}/pages?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{"visitors" => 3, "name" => "/"},
               %{"visitors" => 2, "name" => "/register"},
               %{"visitors" => 1, "name" => "/contact"},
               %{"visitors" => 1, "name" => "/landing"}
             ]

      filters = Jason.encode!([[:is, "event:hostname", ["d.example.com"]]])
      conn = get(conn1, "/api/stats/#{site.domain}/pages?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{"visitors" => 2, "name" => "/register"},
               %{"visitors" => 1, "name" => "/"}
             ]
    end

    test "returns top pages with :is filter on custom pageview props", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/blog/john-1",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          pathname: "/blog/other-post",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview, user_id: 123, pathname: "/")
      ])

      filters = Jason.encode!([[:is, "event:props:author", ["John Doe"]]])
      conn = get(conn, "/api/stats/#{site.domain}/pages?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{"visitors" => 1, "name" => "/blog/john-1"}
             ]
    end

    test "returns top pages with :is_not filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          pathname: "/blog/john-1",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          pathname: "/blog/other-post",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview, pathname: "/")
      ])

      filters = Jason.encode!([[:is_not, "event:props:author", ["John Doe"]]])
      conn = get(conn, "/api/stats/#{site.domain}/pages?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{"visitors" => 1, "name" => "/"},
               %{"visitors" => 1, "name" => "/blog/other-post"}
             ]
    end

    test "returns top pages with :matches_wildcard filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          pathname: "/1",
          "meta.key": ["prop"],
          "meta.value": ["bar"]
        ),
        build(:pageview,
          pathname: "/2",
          "meta.key": ["prop"],
          "meta.value": ["foobar"]
        ),
        build(:pageview,
          pathname: "/3",
          "meta.key": ["prop"],
          "meta.value": ["baar"]
        ),
        build(:pageview,
          pathname: "/4",
          "meta.key": ["another"],
          "meta.value": ["bar"]
        ),
        build(:pageview, pathname: "/5")
      ])

      filters = Jason.encode!([[:contains, "event:props:prop", ["bar"]]])
      conn = get(conn, "/api/stats/#{site.domain}/pages?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{"visitors" => 1, "name" => "/1"},
               %{"visitors" => 1, "name" => "/2"}
             ]
    end

    test "returns top pages with :matches_member filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          pathname: "/1",
          "meta.key": ["prop"],
          "meta.value": ["bar"]
        ),
        build(:pageview,
          pathname: "/2",
          "meta.key": ["prop"],
          "meta.value": ["foobar"]
        ),
        build(:pageview,
          pathname: "/3",
          "meta.key": ["prop"],
          "meta.value": ["baar"]
        ),
        build(:pageview,
          pathname: "/4",
          "meta.key": ["another"],
          "meta.value": ["bar"]
        ),
        build(:pageview, pathname: "/5"),
        build(:pageview,
          pathname: "/6",
          "meta.key": ["prop"],
          "meta.value": ["near"]
        )
      ])

      filters = Jason.encode!([[:contains, "event:props:prop", ["bar", "nea"]]])
      conn = get(conn, "/api/stats/#{site.domain}/pages?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{"visitors" => 1, "name" => "/1"},
               %{"visitors" => 1, "name" => "/2"},
               %{"visitors" => 1, "name" => "/6"}
             ]
    end

    test "returns top pages with multiple filters on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          pathname: "/1",
          "meta.key": ["prop", "number"],
          "meta.value": ["bar", "1"]
        ),
        build(:pageview,
          pathname: "/2",
          "meta.key": ["prop", "number"],
          "meta.value": ["bar", "2"]
        ),
        build(:pageview,
          pathname: "/3",
          "meta.key": ["prop"],
          "meta.value": ["bar"]
        ),
        build(:pageview,
          pathname: "/4",
          "meta.key": ["number"],
          "meta.value": ["bar"]
        ),
        build(:pageview, pathname: "/5")
      ])

      filters =
        Jason.encode!([
          [:is, "event:props:prop", ["bar"]],
          [:is, "event:props:number", ["1"]]
        ])

      conn = get(conn, "/api/stats/#{site.domain}/pages?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{"visitors" => 1, "name" => "/1"}
             ]
    end

    test "calculates bounce_rate and time_on_page with :is filter on custom pageview props",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/blog/john-1",
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/blog",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:pageview,
          pathname: "/blog/john-2",
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        build(:pageview,
          pathname: "/blog/john-2",
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          user_id: 456,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/blog",
          user_id: 456,
          timestamp: ~N[2021-01-01 00:10:00]
        )
      ])

      filters = Jason.encode!([[:is, "event:props:author", ["John Doe"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}&detailed=true"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "/blog/john-2",
                 "visitors" => 2,
                 "pageviews" => 2,
                 "bounce_rate" => 0,
                 "time_on_page" => 600,
                 "scroll_depth" => nil
               },
               %{
                 "name" => "/blog/john-1",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => 0,
                 "time_on_page" => 60,
                 "scroll_depth" => nil
               }
             ]
    end

    test "calculates bounce_rate and time_on_page with :is_not filter on custom pageview props",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/blog",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/blog/john-1",
          user_id: @user_id,
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:pageview,
          pathname: "/blog/other-post",
          user_id: @user_id,
          "meta.key": ["author"],
          "meta.value": ["other"],
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        build(:pageview,
          pathname: "/blog",
          user_id: 456,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/blog/john-1",
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          user_id: 456,
          timestamp: ~N[2021-01-01 00:03:00]
        )
      ])

      filters = Jason.encode!([[:is_not, "event:props:author", ["John Doe"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}&detailed=true"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "/blog",
                 "visitors" => 2,
                 "pageviews" => 2,
                 "bounce_rate" => 0,
                 "time_on_page" => 120.0,
                 "scroll_depth" => nil
               },
               %{
                 "name" => "/blog/other-post",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => 0,
                 "time_on_page" => nil,
                 "scroll_depth" => nil
               }
             ]
    end

    test "calculates bounce_rate and time_on_page with :is (none) filter on custom pageview props",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/blog",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/blog/john-1",
          user_id: @user_id,
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:pageview,
          pathname: "/blog/other-post",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        build(:pageview,
          pathname: "/blog",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      filters = Jason.encode!([[:is, "event:props:author", ["(none)"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}&detailed=true"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "/blog",
                 "visitors" => 2,
                 "pageviews" => 2,
                 "bounce_rate" => 50,
                 "time_on_page" => 60,
                 "scroll_depth" => nil
               },
               %{
                 "name" => "/blog/other-post",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => 0,
                 "time_on_page" => nil,
                 "scroll_depth" => nil
               }
             ]
    end

    test "calculates bounce_rate and time_on_page with :is_not (none) filter on custom pageview props",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/blog/john-1",
          user_id: @user_id,
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/blog",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:pageview,
          pathname: "/blog/other-post",
          "meta.key": ["author"],
          "meta.value": ["other"],
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        build(:pageview,
          pathname: "/blog/other-post",
          "meta.key": ["author"],
          "meta.value": [""],
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      filters = Jason.encode!([[:is_not, "event:props:author", ["(none)"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}&detailed=true"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "/blog/other-post",
                 "visitors" => 2,
                 "pageviews" => 2,
                 "bounce_rate" => 100,
                 "time_on_page" => nil,
                 "scroll_depth" => nil
               },
               %{
                 "name" => "/blog/john-1",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => 0,
                 "time_on_page" => 60,
                 "scroll_depth" => nil
               }
             ]
    end

    test "returns top pages with :not_member filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          pathname: "/chrome",
          "meta.key": ["browser"],
          "meta.value": ["Chrome"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/chrome",
          "meta.key": ["browser"],
          "meta.value": ["Chrome"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/safari",
          "meta.key": ["browser"],
          "meta.value": ["Safari"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/firefox",
          "meta.key": ["browser"],
          "meta.value": ["Firefox"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/firefox",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      filters = Jason.encode!([[:is_not, "event:props:browser", ["Chrome", "Safari"]]])

      conn =
        get(conn, "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "/firefox",
                 "visitors" => 2
               }
             ]
    end

    test "returns top pages with :not_member filter on custom pageview props including (none) value",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/chrome",
          "meta.key": ["browser"],
          "meta.value": ["Chrome"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/chrome",
          "meta.key": ["browser"],
          "meta.value": ["Chrome"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/safari",
          "meta.key": ["browser"],
          "meta.value": ["Safari"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/no-browser-prop",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      filters = Jason.encode!([[:is_not, "event:props:browser", ["Chrome", "(none)"]]])

      conn =
        get(conn, "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "/safari",
                 "visitors" => 1
               }
             ]
    end

    test "calculates bounce_rate and time_on_page for pages filtered by page path",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/about",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:pageview,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        build(:pageview,
          pathname: "/",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/about",
          timestamp: ~N[2021-01-01 00:10:00]
        )
      ])

      filters = Jason.encode!([[:is, "event:page", ["/"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}&detailed=true"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "/",
                 "visitors" => 2,
                 "pageviews" => 3,
                 "bounce_rate" => 50,
                 "time_on_page" => 60,
                 "scroll_depth" => nil
               }
             ]
    end

    test "calculates scroll_depth", %{conn: conn, site: site} do
      t0 = ~N[2020-01-01 00:00:00]
      [t1, t2, t3] = for i <- 1..3, do: NaiveDateTime.add(t0, i, :minute)

      populate_stats(site, [
        build(:pageview, user_id: 12, pathname: "/blog", timestamp: t0),
        build(:engagement, user_id: 12, pathname: "/blog", timestamp: t1, scroll_depth: 20),
        build(:pageview, user_id: 12, pathname: "/another", timestamp: t1),
        build(:engagement, user_id: 12, pathname: "/another", timestamp: t2, scroll_depth: 24),
        build(:pageview, user_id: 34, pathname: "/blog", timestamp: t0),
        build(:engagement, user_id: 34, pathname: "/blog", timestamp: t1, scroll_depth: 17),
        build(:pageview, user_id: 34, pathname: "/another", timestamp: t1),
        build(:engagement, user_id: 34, pathname: "/another", timestamp: t2, scroll_depth: 26),
        build(:pageview, user_id: 34, pathname: "/blog", timestamp: t2),
        build(:engagement, user_id: 34, pathname: "/blog", timestamp: t3, scroll_depth: 60),
        build(:pageview, user_id: 56, pathname: "/blog", timestamp: t0),
        build(:engagement, user_id: 56, pathname: "/blog", timestamp: t1, scroll_depth: 100)
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2020-01-01&detailed=true&order_by=#{Jason.encode!([["scroll_depth", "asc"]])}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "/another",
                 "visitors" => 2,
                 "pageviews" => 2,
                 "bounce_rate" => 0,
                 "time_on_page" => 60,
                 "scroll_depth" => 25
               },
               %{
                 "name" => "/blog",
                 "visitors" => 3,
                 "pageviews" => 4,
                 "bounce_rate" => 33,
                 "time_on_page" => 60,
                 "scroll_depth" => 60
               }
             ]
    end

    test "does not return scroll depth (in detailed mode) when site.scroll_depth_visible_at=nil",
         %{conn: conn, user: user} do
      site = new_site(owner: user)

      populate_stats(site, [build(:pageview)])

      pages =
        conn
        |> get("/api/stats/#{site.domain}/pages?detailed=true")
        |> json_response(200)
        |> Map.get("results")

      assert List.first(pages) == %{
               "bounce_rate" => 100,
               "name" => "/",
               "pageviews" => 1,
               "time_on_page" => nil,
               "visitors" => 1
             }
    end

    @tag skip: "To be re-enabled in the next PR"
    test "calculates scroll_depth from native and imported data combined", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, user_id: @user_id, pathname: "/blog", timestamp: ~N[2020-01-01 00:00:00]),
        build(:engagement,
          user_id: @user_id,
          pathname: "/blog",
          timestamp: ~N[2020-01-01 00:00:00],
          scroll_depth: 80
        ),
        build(:imported_pages,
          date: ~D[2020-01-01],
          visitors: 3,
          pageviews: 3,
          time_on_page: 90,
          page: "/blog",
          scroll_depth: 120,
          pageleave_visitors: 3
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2020-01-01&detailed=true&with_imported=true&order_by=#{Jason.encode!([["scroll_depth", "desc"]])}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "/blog",
                 "visitors" => 4,
                 "pageviews" => 4,
                 "bounce_rate" => 100,
                 "time_on_page" => 30.0,
                 "scroll_depth" => 50
               }
             ]
    end

    @tag skip: "To be re-enabled in the next PR"
    test "handles missing scroll_depth data from native and imported sources", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: @user_id,
          pathname: "/native-and-imported",
          timestamp: ~N[2020-01-01 00:00:00]
        ),
        build(:engagement,
          user_id: @user_id,
          pathname: "/native-and-imported",
          timestamp: ~N[2020-01-01 00:01:00],
          scroll_depth: 80
        ),
        build(:pageview,
          user_id: @user_id,
          pathname: "/native-only",
          timestamp: ~N[2020-01-01 00:01:00]
        ),
        build(:engagement,
          user_id: @user_id,
          pathname: "/native-only",
          timestamp: ~N[2020-01-01 00:02:00],
          scroll_depth: 40
        ),
        build(:imported_pages,
          date: ~D[2020-01-01],
          visitors: 4,
          pageviews: 4,
          time_on_page: 180,
          page: "/native-and-imported",
          scroll_depth: 120,
          pageleave_visitors: 3
        ),
        build(:imported_pages,
          date: ~D[2020-01-01],
          visitors: 20,
          pageviews: 30,
          time_on_page: 300,
          page: "/imported-only",
          scroll_depth: 100,
          pageleave_visitors: 10
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2020-01-01&detailed=true&with_imported=true&order_by=#{Jason.encode!([["scroll_depth", "desc"]])}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "/native-and-imported",
                 "visitors" => 5,
                 "pageviews" => 5,
                 "bounce_rate" => 0,
                 "time_on_page" => 48,
                 "scroll_depth" => 50
               },
               %{
                 "name" => "/native-only",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => 0,
                 "time_on_page" => nil,
                 "scroll_depth" => 40
               },
               %{
                 "name" => "/imported-only",
                 "visitors" => 20,
                 "pageviews" => 30,
                 "bounce_rate" => 0,
                 "time_on_page" => 10.0,
                 "scroll_depth" => 10
               }
             ]
    end

    @tag skip: "To be re-enabled in the next PR"
    test "can query scroll depth only from imported data, ignoring rows where scroll depth doesn't exist",
         %{
           conn: conn,
           site: site
         } do
      populate_stats(site, [
        build(:imported_pages,
          date: ~D[2020-01-01],
          visitors: 10,
          pageviews: 10,
          page: "/blog",
          scroll_depth: 100,
          pageleave_visitors: 10
        ),
        build(:imported_pages,
          date: ~D[2020-01-01],
          visitors: 100,
          pageviews: 150,
          page: "/blog",
          scroll_depth: nil
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=7d&date=2020-01-02&detailed=true&with_imported=true"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "/blog",
                 "visitors" => 110,
                 "pageviews" => 160,
                 "bounce_rate" => 0,
                 "time_on_page" => 0.125,
                 "scroll_depth" => 10
               }
             ]
    end

    test "can filter using the | (OR) filter",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/irrelevant",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:pageview,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        build(:pageview,
          pathname: "/",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/about",
          timestamp: ~N[2021-01-01 00:10:00]
        )
      ])

      filters = Jason.encode!([[:is, "event:page", ["/", "/about"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}&detailed=true"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "/",
                 "visitors" => 2,
                 "pageviews" => 3,
                 "bounce_rate" => 50,
                 "time_on_page" => 60,
                 "scroll_depth" => nil
               },
               %{
                 "name" => "/about",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => 100,
                 "time_on_page" => nil,
                 "scroll_depth" => nil
               }
             ]
    end

    test "can filter using the not_member filter type",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/irrelevant",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:pageview,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        build(:pageview,
          pathname: "/",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/about",
          timestamp: ~N[2021-01-01 00:10:00]
        )
      ])

      filters = Jason.encode!([[:is_not, "event:page", ["/irrelevant", "/about"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}&detailed=true"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "/",
                 "visitors" => 2,
                 "pageviews" => 3,
                 "bounce_rate" => 50,
                 "time_on_page" => 60,
                 "scroll_depth" => nil
               }
             ]
    end

    test "can filter using the matches_member filter type",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/blog/post-1",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/blog/post-2",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:pageview,
          pathname: "/",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/articles/post-1",
          timestamp: ~N[2021-01-01 00:10:00]
        ),
        build(:pageview,
          pathname: "/articles/post-1",
          timestamp: ~N[2021-01-01 00:10:00]
        )
      ])

      filters = Jason.encode!([[:contains, "event:page", ["/blog/", "/articles/"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}&detailed=true"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "/articles/post-1",
                 "visitors" => 2,
                 "pageviews" => 2,
                 "bounce_rate" => 100,
                 "time_on_page" => nil,
                 "scroll_depth" => nil
               },
               %{
                 "name" => "/blog/post-1",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => 0,
                 "time_on_page" => 60,
                 "scroll_depth" => nil
               },
               %{
                 "name" => "/blog/post-2",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => 0,
                 "time_on_page" => nil,
                 "scroll_depth" => nil
               }
             ]
    end

    test "page filter escapes brackets",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/blog/(/post-1",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/blog/(/post-2",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:pageview,
          pathname: "/",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      filters = Jason.encode!([[:contains, "event:page", ["/blog/(/", "/blog/)/"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}&detailed=true"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "/blog/(/post-1",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => 0,
                 "time_on_page" => 60,
                 "scroll_depth" => nil
               },
               %{
                 "name" => "/blog/(/post-2",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => 0,
                 "time_on_page" => nil,
                 "scroll_depth" => nil
               }
             ]
    end

    test "can filter using the not_matches_member filter type",
         %{conn: conn, site: site} do
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

      filters = Jason.encode!([[:contains_not, "event:page", ["/blog/", "/articles/"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}&detailed=true"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "/",
                 "visitors" => 2,
                 "pageviews" => 2,
                 "bounce_rate" => 50,
                 "time_on_page" => 600,
                 "scroll_depth" => nil
               },
               %{
                 "name" => "/about",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => 0,
                 "time_on_page" => nil,
                 "scroll_depth" => nil
               }
             ]
    end

    test "returns top pages by visitors with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/"),
        build(:imported_pages, page: "/"),
        build(:pageview, pathname: "/register"),
        build(:pageview, pathname: "/register"),
        build(:imported_pages, page: "/register"),
        build(:pageview, pathname: "/contact")
      ])

      conn1 = get(conn, "/api/stats/#{site.domain}/pages?period=day")

      assert json_response(conn1, 200)["results"] == [
               %{"visitors" => 3, "name" => "/"},
               %{"visitors" => 2, "name" => "/register"},
               %{"visitors" => 1, "name" => "/contact"}
             ]

      conn2 = get(conn, "/api/stats/#{site.domain}/pages?period=day&with_imported=true")

      assert json_response(conn2, 200)["results"] == [
               %{"visitors" => 4, "name" => "/"},
               %{"visitors" => 3, "name" => "/register"},
               %{"visitors" => 1, "name" => "/contact"}
             ]
    end

    @tag skip: "To be re-enabled in the next PR"
    test "returns scroll depth warning code", %{conn: conn, site: site} do
      Plausible.Sites.set_scroll_depth_visible_at(site)

      conn =
        get(conn, "/api/stats/#{site.domain}/pages?period=day&detailed=true&with_imported=true")

      response = json_response(conn, 200)

      assert response["meta"]["metric_warnings"]["scroll_depth"]["code"] ==
               "no_imported_scroll_depth"
    end

    @tag skip: "To be re-enabled in the next PR"
    test "returns imported pages with a pageview goal filter", %{conn: conn, site: site} do
      insert(:goal, site: site, page_path: "/blog**")

      populate_stats(site, [
        build(:imported_pages, page: "/blog"),
        build(:imported_pages, page: "/not-this"),
        build(:imported_pages, page: "/blog/post-1", visitors: 2),
        build(:imported_visitors, visitors: 4)
      ])

      filters = Jason.encode!([[:is, "event:goal", ["Visit /blog**"]]])
      q = "?period=day&filters=#{filters}&with_imported=true"
      conn = get(conn, "/api/stats/#{site.domain}/pages#{q}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "visitors" => 2,
                 "name" => "/blog/post-1",
                 "conversion_rate" => 100.0,
                 "total_visitors" => 2
               },
               %{
                 "visitors" => 1,
                 "name" => "/blog",
                 "conversion_rate" => 100.0,
                 "total_visitors" => 1
               }
             ]
    end

    test "calculates bounce rate and time on page for pages", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/some-other-page",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          pathname: "/",
          timestamp: ~N[2021-01-01 00:15:00]
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&detailed=true"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "bounce_rate" => 50.0,
                 "time_on_page" => 900.0,
                 "visitors" => 2,
                 "pageviews" => 2,
                 "name" => "/",
                 "scroll_depth" => nil
               },
               %{
                 "bounce_rate" => 0,
                 "time_on_page" => nil,
                 "visitors" => 1,
                 "pageviews" => 1,
                 "name" => "/some-other-page",
                 "scroll_depth" => nil
               }
             ]
    end

    test "filtering by hostname, excludes a page on different hostname", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          timestamp: ~N[2021-01-01 05:01:00],
          pathname: "/about",
          hostname: "blog.example.com",
          user_id: @user_id
        ),
        build(:pageview,
          timestamp: ~N[2021-01-01 05:01:02],
          pathname: "/hello",
          hostname: "example.com",
          user_id: @user_id
        ),
        build(:pageview,
          timestamp: ~N[2021-01-01 05:01:02],
          pathname: "/about",
          hostname: "blog.example.com"
        )
      ])

      filters = Jason.encode!([[:is, "event:hostname", ["blog.example.com"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&detailed=true&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "bounce_rate" => 50,
                 "name" => "/about",
                 "pageviews" => 2,
                 "time_on_page" => nil,
                 "visitors" => 2,
                 "scroll_depth" => nil
               }
             ]
    end

    test "calculates bounce rate and time on page for pages when filtered by hostname", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        # session 1
        build(:pageview,
          pathname: "/about-blog",
          hostname: "blog.example.com",
          user_id: @user_id + 1,
          timestamp: ~N[2021-01-01 00:01:00]
        ),

        # session 2
        build(:pageview,
          pathname: "/about-blog",
          hostname: "blog.example.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:pageview,
          pathname: "/about",
          hostname: "example.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:10:00]
        ),
        build(:pageview,
          pathname: "/about-blog",
          hostname: "blog.example.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          pathname: "/exit-blog",
          hostname: "blog.example.com",
          timestamp: ~N[2021-01-01 00:20:00],
          user_id: @user_id
        ),
        build(:pageview,
          pathname: "/about",
          hostname: "example.com",
          timestamp: ~N[2021-01-01 00:22:00],
          user_id: @user_id
        ),
        build(:pageview,
          pathname: "/exit",
          hostname: "example.com",
          timestamp: ~N[2021-01-01 00:25:00],
          user_id: @user_id
        ),

        # session 3
        build(:pageview,
          pathname: "/about",
          hostname: "example.com",
          user_id: @user_id + 2,
          timestamp: ~N[2021-01-01 00:01:00]
        )
      ])

      filters = Jason.encode!([[:is, "event:hostname", ["blog.example.com"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&detailed=true&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "bounce_rate" => 50,
                 "name" => "/about-blog",
                 "pageviews" => 3,
                 "time_on_page" => 1140.0,
                 "visitors" => 2,
                 "scroll_depth" => nil
               },
               %{
                 "bounce_rate" => 0,
                 "name" => "/exit-blog",
                 "pageviews" => 1,
                 "time_on_page" => nil,
                 "visitors" => 1,
                 "scroll_depth" => nil
               }
             ]
    end

    test "doesn't calculate time on page with only single page visits", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/", user_id: @user_id, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, pathname: "/", user_id: @user_id, timestamp: ~N[2021-01-01 00:10:00])
      ])

      assert [%{"name" => "/", "time_on_page" => nil}] =
               conn
               |> get("/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&detailed=true")
               |> json_response(200)
               |> Map.get("results")
    end

    test "ignores page refresh when calculating time on page", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:00:00], pathname: "/"),
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:01:00], pathname: "/"),
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:02:00], pathname: "/"),
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:03:00], pathname: "/exit")
      ])

      assert [
               %{"name" => "/", "time_on_page" => _three_minutes = 180.0},
               %{"name" => "/exit", "time_on_page" => nil}
             ] =
               conn
               |> get("/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&detailed=true")
               |> json_response(200)
               |> Map.get("results")
    end

    test "calculates time on page per unique transition within session", %{conn: conn, site: site} do
      # ┌─p──┬─p2─┬─minus(t2, t)─┬──s─┐
      # │ /a │ /b │          100 │ s1 │
      # │ /a │ /d │          100 │ s2 │ <- these two get treated
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

      assert [
               %{"name" => "/a", "time_on_page" => 100.0},
               %{"name" => "/b", "time_on_page" => nil},
               %{"name" => "/d", "time_on_page" => +0.0}
             ] =
               conn
               |> get("/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&detailed=true")
               |> json_response(200)
               |> Map.get("results")
    end

    test "calculates bounce rate and time on page for pages with imported data", %{
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
          pathname: "/some-other-page",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          pathname: "/",
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:imported_pages,
          page: "/",
          date: ~D[2021-01-01],
          time_on_page: 700
        ),
        build(:imported_entry_pages,
          entry_page: "/",
          date: ~D[2021-01-01],
          entrances: 3,
          bounces: 1
        ),
        build(:imported_pages,
          page: "/some-other-page",
          date: ~D[2021-01-01],
          time_on_page: 60
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&detailed=true&with_imported=true"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "bounce_rate" => 40.0,
                 "time_on_page" => 800.0,
                 "visitors" => 3,
                 "pageviews" => 3,
                 "scroll_depth" => nil,
                 "name" => "/"
               },
               %{
                 "bounce_rate" => 0,
                 "time_on_page" => 60,
                 "visitors" => 2,
                 "pageviews" => 2,
                 "scroll_depth" => nil,
                 "name" => "/some-other-page"
               }
             ]
    end

    test "returns top pages in realtime report", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/page1"),
        build(:pageview, pathname: "/page2"),
        build(:pageview, pathname: "/page1")
      ])

      conn = get(conn, "/api/stats/#{site.domain}/pages?period=realtime")

      assert json_response(conn, 200)["results"] == [
               %{"visitors" => 2, "name" => "/page1"},
               %{"visitors" => 1, "name" => "/page2"}
             ]
    end

    test "calculates conversion_rate when filtering for goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, pathname: "/"),
        build(:pageview, user_id: 2, pathname: "/"),
        build(:pageview, user_id: 3, pathname: "/"),
        build(:event, user_id: 3, name: "Signup")
      ])

      insert(:goal, site: site, event_name: "Signup")
      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      conn = get(conn, "/api/stats/#{site.domain}/pages?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{"total_visitors" => 3, "visitors" => 1, "name" => "/", "conversion_rate" => 33.3}
             ]
    end

    test "filter by :is page with imported data", %{conn: conn, site: site} do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:pageview, user_id: 1, pathname: "/", timestamp: ~N[2021-01-01 12:00:00]),
        build(:pageview, user_id: 1, pathname: "/ignored", timestamp: ~N[2021-01-01 12:01:00]),
        build(:imported_entry_pages,
          entry_page: "/",
          visitors: 1,
          bounces: 1,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages,
          page: "/",
          visitors: 3,
          pageviews: 3,
          time_on_page: 300,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages, page: "/ignored", visitors: 10, date: ~D[2021-01-01])
      ])

      filters = Jason.encode!([[:is, "event:page", ["/"]]])
      q = "?period=day&date=2021-01-01&filters=#{filters}&detailed=true&with_imported=true"

      conn = get(conn, "/api/stats/#{site.domain}/pages#{q}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "bounce_rate" => 50,
                 "name" => "/",
                 "pageviews" => 4,
                 "time_on_page" => 90.0,
                 "visitors" => 4,
                 "scroll_depth" => nil
               }
             ]
    end

    test "filter by :member page with imported data", %{conn: conn, site: site} do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:pageview, user_id: 1, pathname: "/", timestamp: ~N[2021-01-01 12:00:00]),
        build(:pageview, user_id: 1, pathname: "/ignored", timestamp: ~N[2021-01-01 12:01:00]),
        build(:imported_entry_pages,
          entry_page: "/",
          visitors: 1,
          bounces: 1,
          date: ~D[2021-01-01]
        ),
        build(:imported_entry_pages,
          entry_page: "/a",
          visitors: 1,
          bounces: 1,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages,
          page: "/",
          visitors: 3,
          pageviews: 3,
          time_on_page: 300,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages,
          page: "/a",
          visitors: 1,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages, page: "/ignored", visitors: 10, date: ~D[2021-01-01])
      ])

      filters = Jason.encode!([[:is, "event:page", ["/", "/a"]]])
      q = "?period=day&date=2021-01-01&filters=#{filters}&detailed=true&with_imported=true"

      conn = get(conn, "/api/stats/#{site.domain}/pages#{q}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "bounce_rate" => 50,
                 "name" => "/",
                 "pageviews" => 4,
                 "time_on_page" => 90.0,
                 "visitors" => 4,
                 "scroll_depth" => nil
               },
               %{
                 "bounce_rate" => 100,
                 "name" => "/a",
                 "pageviews" => 1,
                 "time_on_page" => 10.0,
                 "visitors" => 1,
                 "scroll_depth" => nil
               }
             ]
    end

    test "filter by :matches_wildcard page with imported data", %{conn: conn, site: site} do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:pageview, user_id: 1, pathname: "/aaa", timestamp: ~N[2021-01-01 12:00:00]),
        build(:pageview, user_id: 1, pathname: "/ignored", timestamp: ~N[2021-01-01 12:01:00]),
        build(:imported_entry_pages,
          entry_page: "/aaa",
          visitors: 1,
          bounces: 1,
          date: ~D[2021-01-01]
        ),
        build(:imported_entry_pages,
          entry_page: "/a",
          visitors: 1,
          bounces: 1,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages,
          page: "/aaa",
          visitors: 3,
          pageviews: 3,
          time_on_page: 300,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages,
          page: "/a",
          visitors: 1,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages, page: "/ignored", visitors: 10, date: ~D[2021-01-01])
      ])

      filters = Jason.encode!([[:contains, "event:page", ["/a"]]])
      q = "?period=day&date=2021-01-01&filters=#{filters}&detailed=true&with_imported=true"

      conn = get(conn, "/api/stats/#{site.domain}/pages#{q}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "bounce_rate" => 50,
                 "name" => "/aaa",
                 "pageviews" => 4,
                 "time_on_page" => 90.0,
                 "visitors" => 4,
                 "scroll_depth" => nil
               },
               %{
                 "bounce_rate" => 100,
                 "name" => "/a",
                 "pageviews" => 1,
                 "time_on_page" => 10.0,
                 "visitors" => 1,
                 "scroll_depth" => nil
               }
             ]
    end

    test "can compare with previous period", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/page1",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page1",
          timestamp: ~N[2021-01-02 00:00:00]
        ),
        build(:pageview,
          pathname: "/page2",
          timestamp: ~N[2021-01-02 00:00:00]
        ),
        build(:pageview,
          pathname: "/page2",
          timestamp: ~N[2021-01-02 00:00:00]
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-02&comparison=previous_period&detailed=true"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "bounce_rate" => 100,
                 "comparison" => %{
                   "bounce_rate" => 0,
                   "pageviews" => 0,
                   "time_on_page" => 0,
                   "visitors" => 0,
                   "scroll_depth" => nil,
                   "change" => %{
                     "bounce_rate" => nil,
                     "pageviews" => 100,
                     "time_on_page" => nil,
                     "visitors" => 100,
                     "scroll_depth" => nil
                   }
                 },
                 "name" => "/page2",
                 "pageviews" => 2,
                 "time_on_page" => nil,
                 "visitors" => 2,
                 "scroll_depth" => nil
               },
               %{
                 "bounce_rate" => 100,
                 "name" => "/page1",
                 "pageviews" => 1,
                 "time_on_page" => nil,
                 "visitors" => 1,
                 "scroll_depth" => nil,
                 "comparison" => %{
                   "bounce_rate" => 100,
                   "pageviews" => 1,
                   "time_on_page" => nil,
                   "visitors" => 1,
                   "scroll_depth" => nil,
                   "change" => %{
                     "bounce_rate" => 0,
                     "pageviews" => 0,
                     "time_on_page" => nil,
                     "visitors" => 0,
                     "scroll_depth" => nil
                   }
                 }
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/entry-pages" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "returns top entry pages by visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/page1",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page1",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page2",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page2",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        )
      ])

      populate_stats(site, [
        build(:pageview,
          pathname: "/page2",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 23:15:00]
        )
      ])

      conn = get(conn, "/api/stats/#{site.domain}/entry-pages?period=day&date=2021-01-01")

      assert json_response(conn, 200)["results"] == [
               %{
                 "visitors" => 2,
                 "visits" => 2,
                 "name" => "/page1",
                 "visit_duration" => 0
               },
               %{
                 "visitors" => 1,
                 "visits" => 2,
                 "name" => "/page2",
                 "visit_duration" => 450
               }
             ]
    end

    test "returns top entry pages filtered by custom pageview props", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/blog",
          user_id: 123,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/blog/john-1",
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          user_id: 123,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:pageview,
          pathname: "/blog/john-2",
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/blog/other-post",
          "meta.key": ["author"],
          "meta.value": ["other"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/blog",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      filters = Jason.encode!([[:is, "event:props:author", ["John Doe"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/entry-pages?period=day&date=2021-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "visitors" => 1,
                 "visits" => 1,
                 "name" => "/blog",
                 "visit_duration" => 60
               },
               %{
                 "visitors" => 1,
                 "visits" => 1,
                 "name" => "/blog/john-2",
                 "visit_duration" => 0
               }
             ]
    end

    test "returns top entry pages by visitors with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/page1",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page1",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page2",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page2",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          pathname: "/page2",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 23:15:00]
        )
      ])

      populate_stats(site, [
        build(:imported_entry_pages,
          entry_page: "/page2",
          date: ~D[2021-01-01],
          entrances: 3,
          visitors: 2,
          visit_duration: 300
        )
      ])

      conn1 = get(conn, "/api/stats/#{site.domain}/entry-pages?period=day&date=2021-01-01")

      assert json_response(conn1, 200)["results"] == [
               %{
                 "visitors" => 2,
                 "visits" => 2,
                 "name" => "/page1",
                 "visit_duration" => 0
               },
               %{
                 "visitors" => 1,
                 "visits" => 2,
                 "name" => "/page2",
                 "visit_duration" => 450
               }
             ]

      conn2 =
        get(
          conn,
          "/api/stats/#{site.domain}/entry-pages?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn2, 200)["results"] == [
               %{
                 "visitors" => 3,
                 "visits" => 5,
                 "name" => "/page2",
                 "visit_duration" => 240.0
               },
               %{
                 "visitors" => 2,
                 "visits" => 2,
                 "name" => "/page1",
                 "visit_duration" => 0
               }
             ]
    end

    test "returns top entry pages by visitors filtered by hostname",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/page1",
          hostname: "en.example.com",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page1",
          hostname: "es.example.com",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page2",
          hostname: "en.example.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page2",
          hostname: "es.example.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          pathname: "/exit",
          hostname: "es.example.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:16:00]
        ),
        build(:pageview,
          pathname: "/page2",
          hostname: "es.example.com",
          timestamp: ~N[2021-01-01 23:15:00]
        )
      ])

      filters = Jason.encode!([[:is, "event:hostname", ["es.example.com"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/entry-pages?period=day&date=2021-01-01&filters=#{filters}"
        )

      # We're going to only join sessions where the exit hostname matches the filter
      assert json_response(conn, 200)["results"] == [
               %{"name" => "/page1", "visit_duration" => 0, "visitors" => 1, "visits" => 1},
               %{"name" => "/page2", "visit_duration" => 0, "visitors" => 1, "visits" => 1}
             ]
    end

    test "bugfix: pagination on /pages filtered by goal", %{conn: conn, site: site} do
      populate_stats(
        site,
        for i <- 1..30 do
          build(:event,
            user_id: i,
            name: "Signup",
            pathname: "/signup/#{String.pad_leading(to_string(i), 2, "0")}",
            timestamp: ~N[2021-01-01 00:01:00]
          )
        end
      )

      insert(:goal, site: site, event_name: "Signup")

      request = fn conn, opts ->
        page = Keyword.fetch!(opts, :page)
        limit = Keyword.fetch!(opts, :limit)
        filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

        conn
        |> get(
          "/api/stats/#{site.domain}/pages?date=2021-01-01&period=day&filters=#{filters}&limit=#{limit}&page=#{page}"
        )
        |> json_response(200)
        |> Map.get("results")
        |> Enum.map(fn %{"name" => "/signup/" <> seq} ->
          seq
        end)
      end

      assert List.first(request.(conn, page: 1, limit: 100)) == "01"
      assert List.last(request.(conn, page: 1, limit: 100)) == "30"
      assert List.last(request.(conn, page: 1, limit: 29)) == "29"
      assert ["01", "02"] = request.(conn, page: 1, limit: 2)
      assert ["03", "04"] = request.(conn, page: 2, limit: 2)
      assert ["01", "02", "03", "04", "05"] = request.(conn, page: 1, limit: 5)
      assert ["06", "07", "08", "09", "10"] = request.(conn, page: 2, limit: 5)
      assert ["11", "12", "13", "14", "15"] = request.(conn, page: 3, limit: 5)
      assert ["20"] = request.(conn, page: 20, limit: 1)
      assert [] = request.(conn, page: 31, limit: 1)
    end

    test "calculates conversion_rate when filtering for goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/page1",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page1",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page2",
          user_id: 3,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page2",
          user_id: 3,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:event,
          name: "Signup",
          user_id: 3,
          timestamp: ~N[2021-01-01 00:15:00]
        )
      ])

      insert(:goal, site: site, event_name: "Signup")
      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/entry-pages?period=day&date=2021-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "total_visitors" => 2,
                 "visitors" => 1,
                 "name" => "/page1",
                 "conversion_rate" => 50.0
               },
               %{
                 "total_visitors" => 1,
                 "visitors" => 1,
                 "name" => "/page2",
                 "conversion_rate" => 100.0
               }
             ]
    end

    test "ignores entry pages from sessions with only custom events", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "Signup",
          timestamp: ~N[2021-01-01 00:15:00],
          pathname: "/"
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/entry-pages?period=day&date=2021-01-01"
        )

      assert json_response(conn, 200)["results"] == []
    end

    test "filter by :matches_member entry_page with imported data", %{conn: conn, site: site} do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:pageview, pathname: "/aaa", timestamp: ~N[2021-01-01 12:00:00]),
        build(:pageview, pathname: "/a", timestamp: ~N[2021-01-01 12:00:00]),
        build(:pageview, pathname: "/ignored", timestamp: ~N[2021-01-01 12:01:00]),
        build(:imported_entry_pages,
          entry_page: "/a",
          visitors: 5,
          entrances: 9,
          visit_duration: 1000,
          date: ~D[2021-01-01]
        ),
        build(:imported_entry_pages,
          entry_page: "/bbb",
          visitors: 2,
          entrances: 2,
          visit_duration: 100,
          date: ~D[2021-01-01]
        )
      ])

      filters = Jason.encode!([[:contains, "visit:entry_page", ["/a", "/b"]]])
      q = "?period=day&date=2021-01-01&filters=#{filters}&detailed=true&with_imported=true"

      conn = get(conn, "/api/stats/#{site.domain}/entry-pages#{q}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "visit_duration" => 100.0,
                 "name" => "/a",
                 "visits" => 10,
                 "visitors" => 6
               },
               %{
                 "visit_duration" => 50.0,
                 "name" => "/bbb",
                 "visits" => 2,
                 "visitors" => 2
               },
               %{
                 "visit_duration" => 0,
                 "name" => "/aaa",
                 "visits" => 1,
                 "visitors" => 1
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/exit-pages" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "returns top exit pages by visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/page1",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page1",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page1",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page2",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        )
      ])

      conn = get(conn, "/api/stats/#{site.domain}/exit-pages?period=day&date=2021-01-01")

      assert json_response(conn, 200)["results"] == [
               %{"name" => "/page1", "visitors" => 2, "visits" => 2, "exit_rate" => 66},
               %{"name" => "/page2", "visitors" => 1, "visits" => 1, "exit_rate" => 100}
             ]
    end

    test "returns top exit pages by ascending visits", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/page1",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page1",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page1",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page2",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/exit-pages?period=day&date=2021-01-01&order_by=#{Jason.encode!([["visits", "asc"]])}"
        )

      assert json_response(conn, 200)["results"] == [
               %{"name" => "/page2", "visitors" => 1, "visits" => 1, "exit_rate" => 100},
               %{"name" => "/page1", "visitors" => 2, "visits" => 2, "exit_rate" => 66}
             ]
    end

    test "returns top exit pages by visitors filtered by hostname",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/page1",
          hostname: "en.example.com",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page1",
          hostname: "es.example.com",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page1",
          hostname: "en.example.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page2",
          hostname: "es.example.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          pathname: "/exit",
          hostname: "en.example.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:16:00]
        )
      ])

      filters = Jason.encode!([[:is, "event:hostname", ["es.example.com"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/exit-pages?period=day&date=2021-01-01&filters=#{filters}"
        )

      # We're going to only join sessions where the entry hostname matches the filter
      assert json_response(conn, 200)["results"] ==
               [%{"name" => "/page1", "visitors" => 1, "visits" => 1}]
    end

    test "returns top exit pages filtered by custom pageview props", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/blog/john-1",
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          user_id: 123,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/",
          user_id: 123,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:pageview,
          pathname: "/blog/other-post",
          "meta.key": ["author"],
          "meta.value": ["other"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      filters = Jason.encode!([[:is, "event:props:author", ["John Doe"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/exit-pages?period=day&date=2021-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{"name" => "/", "visitors" => 1, "visits" => 1}
             ]
    end

    test "returns top exit pages by visitors with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/page1",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page1",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page1",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page2",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        )
      ])

      populate_stats(site, [
        build(:imported_pages,
          page: "/page2",
          date: ~D[2021-01-01],
          pageviews: 4,
          visitors: 2
        ),
        build(:imported_exit_pages,
          exit_page: "/page2",
          date: ~D[2021-01-01],
          exits: 3,
          visitors: 2
        )
      ])

      conn1 = get(conn, "/api/stats/#{site.domain}/exit-pages?period=day&date=2021-01-01")

      assert json_response(conn1, 200)["results"] == [
               %{"name" => "/page1", "visitors" => 2, "visits" => 2, "exit_rate" => 66},
               %{"name" => "/page2", "visitors" => 1, "visits" => 1, "exit_rate" => 100}
             ]

      conn2 =
        get(
          conn,
          "/api/stats/#{site.domain}/exit-pages?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn2, 200)["results"] == [
               %{
                 "name" => "/page2",
                 "visitors" => 3,
                 "visits" => 4,
                 "exit_rate" => 80.0
               },
               %{"name" => "/page1", "visitors" => 2, "visits" => 2, "exit_rate" => 66}
             ]
    end

    test "calculates correct exit rate and conversion_rate when filtering for goal", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Signup",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 1,
          pathname: "/exit1",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 2,
          pathname: "/exit1",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 2,
          pathname: "/exit2",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      insert(:goal, site: site, event_name: "Signup")
      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/exit-pages?period=day&date=2021-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "/exit1",
                 "visitors" => 1,
                 "total_visitors" => 1,
                 "conversion_rate" => 100.0
               },
               %{
                 "name" => "/exit2",
                 "visitors" => 1,
                 "total_visitors" => 1,
                 "conversion_rate" => 100.0
               }
             ]
    end

    test "calculates correct exit rate when filtering for page", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 1,
          pathname: "/exit1",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 2,
          pathname: "/exit1",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 2,
          pathname: "/exit2",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 3,
          pathname: "/exit2",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 3,
          pathname: "/should-not-appear",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      filters = Jason.encode!([[:is, "event:page", ["/exit1"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/exit-pages?period=day&date=2021-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{"name" => "/exit1", "visitors" => 1, "visits" => 1},
               %{"name" => "/exit2", "visitors" => 1, "visits" => 1}
             ]
    end

    test "ignores exit pages from sessions with only custom events", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "Signup",
          timestamp: ~N[2021-01-01 00:15:00],
          pathname: "/"
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/exit-pages?period=day&date=2021-01-01"
        )

      assert json_response(conn, 200)["results"] == []
    end

    test "filter by :is_not exit_page with imported data", %{conn: conn, site: site} do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:pageview, pathname: "/aaa", timestamp: ~N[2021-01-01 12:00:00]),
        build(:pageview, pathname: "/a", timestamp: ~N[2021-01-01 12:00:00]),
        build(:pageview, pathname: "/ignored", timestamp: ~N[2021-01-01 12:01:00]),
        build(:imported_exit_pages,
          exit_page: "/a",
          visitors: 5,
          exits: 9,
          visit_duration: 1000,
          date: ~D[2021-01-01]
        ),
        build(:imported_exit_pages,
          exit_page: "/bbb",
          visitors: 2,
          exits: 2,
          visit_duration: 100,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages, page: "/a", pageviews: 19, date: ~D[2021-01-01]),
        build(:imported_pages, page: "/bbb", pageviews: 2, date: ~D[2021-01-01])
      ])

      filters = Jason.encode!([[:is_not, "visit:exit_page", ["/ignored"]]])
      q = "?period=day&date=2021-01-01&filters=#{filters}&detailed=true&with_imported=true"

      conn = get(conn, "/api/stats/#{site.domain}/exit-pages#{q}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "exit_rate" => 50.0,
                 "name" => "/a",
                 "visits" => 10,
                 "visitors" => 6
               },
               %{
                 "exit_rate" => 100.0,
                 "name" => "/bbb",
                 "visits" => 2,
                 "visitors" => 2
               },
               %{
                 "exit_rate" => 100.0,
                 "name" => "/aaa",
                 "visits" => 1,
                 "visitors" => 1
               }
             ]
    end
  end
end
