defmodule PlausibleWeb.Api.StatsController.PagesTest do
  use PlausibleWeb.ConnCase

  @user_id Enum.random(1000..9999)

  @default_metrics ["visitors", "percentage"]
  @detailed_metrics [
    "visitors",
    "pageviews",
    "bounce_rate",
    "time_on_page",
    "scroll_depth",
    "percentage"
  ]
  @goal_filter_metrics ["visitors", "group_conversion_rate", "total_visitors"]

  defp query_pages(conn, site, opts) do
    params = %{
      "dimensions" => Keyword.get(opts, :dimensions, ["event:page"]),
      "date_range" => Keyword.get(opts, :date_range, "all"),
      "relative_date" => Keyword.get(opts, :relative_date, nil),
      "filters" => Keyword.get(opts, :filters, []),
      "metrics" => Keyword.get(opts, :metrics, @default_metrics),
      "include" => Keyword.get(opts, :include, nil),
      "pagination" => Keyword.get(opts, :pagination, nil),
      "order_by" => Keyword.get(opts, :order_by, nil)
    }

    conn
    |> post("/api/stats/#{site.domain}/query", params)
    |> json_response(200)
  end

  describe "GET /api/stats/:domain/pages" do
    setup [
      :create_user,
      :log_in,
      :create_site,
      :create_legacy_site_import
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

      response = query_pages(conn, site, date_range: "day")

      assert response["results"] == [
               %{"dimensions" => ["/"], "metrics" => [3, 50.0]},
               %{"dimensions" => ["/register"], "metrics" => [2, 33.33]},
               %{"dimensions" => ["/contact"], "metrics" => [1, 16.67]}
             ]
    end

    test "returns top pages by visitors by hostname", %{conn: conn, site: site} do
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

      response =
        query_pages(conn, site,
          date_range: "day",
          filters: [["contains", "event:hostname", [".example.com"]]],
          order_by: [["visitors", "desc"], ["event:page", "asc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["/"], "metrics" => [3, 50.0]},
               %{"dimensions" => ["/register"], "metrics" => [2, 33.33]},
               %{"dimensions" => ["/contact"], "metrics" => [1, 16.67]},
               %{"dimensions" => ["/landing"], "metrics" => [1, 16.67]}
             ]

      response =
        query_pages(conn, site,
          date_range: "day",
          filters: [["is", "event:hostname", ["d.example.com"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["/register"], "metrics" => [2, 66.67]},
               %{"dimensions" => ["/"], "metrics" => [1, 33.33]}
             ]
    end

    test "returns top pages broken down by hostname and page", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/docs", hostname: "main.example.com"),
        build(:pageview, pathname: "/docs", hostname: "main.example.com"),
        build(:pageview, pathname: "/docs", hostname: "secondary.example.com")
      ])

      response =
        query_pages(conn, site,
          date_range: "day",
          dimensions: ["event:hostname", "event:page"],
          metrics: ["visitors", "bounce_rate"]
        )

      assert response["results"] == [
               %{"dimensions" => ["main.example.com", "/docs"], "metrics" => [2, 100]},
               %{"dimensions" => ["secondary.example.com", "/docs"], "metrics" => [1, 100]}
             ]
    end

    test "correctly computes bounce_rate when broken down by hostname and page",
         %{conn: conn, site: site} do
      populate_stats(site, [
        # 1: 2 pageviews on primary (no bounce)
        build(:pageview,
          pathname: "/docs",
          hostname: "main.example.com",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/docs",
          hostname: "main.example.com",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        # 2: single pageview on primary (bounce)
        build(:pageview,
          pathname: "/docs",
          hostname: "main.example.com",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        # 3: single pageview on secondary (bounce)
        build(:pageview,
          pathname: "/docs",
          hostname: "secondary.example.com",
          user_id: 3,
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      response =
        query_pages(conn, site,
          dimensions: ["event:hostname", "event:page"],
          metrics: ["visitors", "bounce_rate"]
        )

      assert response["results"] == [
               %{"dimensions" => ["main.example.com", "/docs"], "metrics" => [2, 50]},
               %{"dimensions" => ["secondary.example.com", "/docs"], "metrics" => [1, 100]}
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

      response =
        query_pages(conn, site,
          date_range: "day",
          filters: [["is", "event:props:author", ["John Doe"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["/blog/john-1"], "metrics" => [1, 100.0]}
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

      response =
        query_pages(conn, site,
          date_range: "day",
          filters: [["is_not", "event:props:author", ["John Doe"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["/"], "metrics" => [1, 50.0]},
               %{"dimensions" => ["/blog/other-post"], "metrics" => [1, 50.0]}
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

      response =
        query_pages(conn, site,
          date_range: "day",
          filters: [["contains", "event:props:prop", ["bar"]]],
          order_by: [["visitors", "desc"], ["event:page", "asc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["/1"], "metrics" => [1, 50.0]},
               %{"dimensions" => ["/2"], "metrics" => [1, 50.0]}
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

      response =
        query_pages(conn, site,
          date_range: "day",
          filters: [["contains", "event:props:prop", ["bar", "nea"]]],
          order_by: [["visitors", "desc"], ["event:page", "asc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["/1"], "metrics" => [1, 33.33]},
               %{"dimensions" => ["/2"], "metrics" => [1, 33.33]},
               %{"dimensions" => ["/6"], "metrics" => [1, 33.33]}
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

      response =
        query_pages(conn, site,
          date_range: "day",
          filters: [
            ["is", "event:props:prop", ["bar"]],
            ["is", "event:props:number", ["1"]]
          ]
        )

      assert response["results"] == [
               %{"dimensions" => ["/1"], "metrics" => [1, 100.0]}
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
        build(:engagement,
          pathname: "/blog/john-1",
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00],
          engagement_time: 60_000
        ),
        build(:pageview,
          pathname: "/blog",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:engagement,
          pathname: "/blog",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:02:00],
          engagement_time: 60_000
        ),
        build(:pageview,
          pathname: "/blog/john-2",
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        build(:engagement,
          pathname: "/blog/john-2",
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:02:30],
          engagement_time: 30_000
        ),
        build(:pageview,
          pathname: "/blog/john-2",
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          user_id: 456,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:engagement,
          pathname: "/blog/john-2",
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          user_id: 456,
          timestamp: ~N[2021-01-01 00:10:00],
          engagement_time: 600_000
        ),
        build(:pageview,
          pathname: "/blog",
          user_id: 456,
          timestamp: ~N[2021-01-01 00:10:00]
        ),
        build(:engagement,
          pathname: "/blog",
          user_id: 456,
          timestamp: ~N[2021-01-01 00:10:30],
          engagement_time: 30_000
        )
      ])

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["is", "event:props:author", ["John Doe"]]],
          metrics: @detailed_metrics
        )

      assert response["results"] == [
               %{"dimensions" => ["/blog/john-2"], "metrics" => [2, 2, 0, 315, 0, 100.0]},
               %{"dimensions" => ["/blog/john-1"], "metrics" => [1, 1, 0, 60, 0, 50.0]}
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
        build(:engagement,
          pathname: "/blog",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00],
          engagement_time: 60_000
        ),
        build(:pageview,
          pathname: "/blog/john-1",
          user_id: @user_id,
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:engagement,
          pathname: "/blog/john-1",
          user_id: @user_id,
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          timestamp: ~N[2021-01-01 00:02:00],
          engagement_time: 60_000
        ),
        build(:pageview,
          pathname: "/blog/other-post",
          user_id: @user_id,
          "meta.key": ["author"],
          "meta.value": ["other"],
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        build(:engagement,
          pathname: "/blog/other-post",
          user_id: @user_id,
          "meta.key": ["author"],
          "meta.value": ["other"],
          timestamp: ~N[2021-01-01 00:02:30],
          engagement_time: 30_000
        ),
        build(:pageview,
          pathname: "/blog",
          user_id: 456,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:engagement,
          pathname: "/blog",
          user_id: 456,
          timestamp: ~N[2021-01-01 00:03:00],
          engagement_time: 180_000
        ),
        build(:pageview,
          pathname: "/blog/john-1",
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          user_id: 456,
          timestamp: ~N[2021-01-01 00:03:00]
        ),
        build(:engagement,
          pathname: "/blog/john-1",
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          user_id: 456,
          timestamp: ~N[2021-01-01 00:03:30],
          engagement_time: 30_000
        )
      ])

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["is_not", "event:props:author", ["John Doe"]]],
          metrics: @detailed_metrics
        )

      assert response["results"] == [
               %{"dimensions" => ["/blog"], "metrics" => [2, 2, 0, 120, 0, 100.0]},
               %{"dimensions" => ["/blog/other-post"], "metrics" => [1, 1, 0, 30, 0, 50.0]}
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
        build(:engagement,
          pathname: "/blog",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00],
          engagement_time: 60_000
        ),
        build(:pageview,
          pathname: "/blog/john-1",
          user_id: @user_id,
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:engagement,
          pathname: "/blog/john-1",
          user_id: @user_id,
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          timestamp: ~N[2021-01-01 00:02:00],
          engagement_time: 60_000
        ),
        build(:pageview,
          pathname: "/blog/other-post",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        build(:engagement,
          pathname: "/blog/other-post",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:02:30],
          engagement_time: 30_000
        ),
        build(:pageview,
          pathname: "/blog",
          user_id: 456,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:engagement,
          pathname: "/blog",
          user_id: 456,
          timestamp: ~N[2021-01-01 00:00:30],
          engagement_time: 30_000
        )
      ])

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["is", "event:props:author", ["(none)"]]],
          metrics: @detailed_metrics
        )

      assert response["results"] == [
               %{"dimensions" => ["/blog"], "metrics" => [2, 2, 50, 45, 0, 100.0]},
               %{"dimensions" => ["/blog/other-post"], "metrics" => [1, 1, 0, 30, 0, 50.0]}
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
        build(:engagement,
          pathname: "/blog/john-1",
          user_id: @user_id,
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          timestamp: ~N[2021-01-01 00:01:00],
          engagement_time: 60_000
        ),
        build(:pageview,
          pathname: "/blog",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:engagement,
          pathname: "/blog",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:02:00],
          engagement_time: 60_000
        ),
        build(:pageview,
          pathname: "/blog/other-post",
          "meta.key": ["author"],
          "meta.value": ["other"],
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        build(:engagement,
          pathname: "/blog/other-post",
          "meta.key": ["author"],
          "meta.value": ["other"],
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:02:30],
          engagement_time: 30_000
        ),
        build(:pageview,
          pathname: "/blog/other-post",
          "meta.key": ["author"],
          "meta.value": [""],
          user_id: 456,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:engagement,
          pathname: "/blog/other-post",
          "meta.key": ["author"],
          "meta.value": [""],
          user_id: 456,
          timestamp: ~N[2021-01-01 00:00:30],
          engagement_time: 30_000
        )
      ])

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["is_not", "event:props:author", ["(none)"]]],
          metrics: @detailed_metrics
        )

      assert response["results"] == [
               %{"dimensions" => ["/blog/other-post"], "metrics" => [2, 2, 100, 30, 0, 100.0]},
               %{"dimensions" => ["/blog/john-1"], "metrics" => [1, 1, 0, 60, 0, 50.0]}
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

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["is_not", "event:props:browser", ["Chrome", "Safari"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["/firefox"], "metrics" => [2, 100.0]}
             ]

      assert %{
               "date_range" => ["2021-01-01T00:00:00Z", "2021-01-01T23:59:59Z"]
             } = response["query"]
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

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["is_not", "event:props:browser", ["Chrome", "(none)"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["/safari"], "metrics" => [1, 100.0]}
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
        build(:engagement,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00],
          engagement_time: 60_000
        ),
        build(:pageview,
          pathname: "/about",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:engagement,
          pathname: "/about",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:02:00],
          engagement_time: 60_000
        ),
        build(:pageview,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        build(:engagement,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:02:30],
          engagement_time: 30_000
        ),
        build(:pageview,
          pathname: "/",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/about",
          user_id: 456,
          timestamp: ~N[2021-01-01 00:10:00]
        ),
        build(:engagement,
          pathname: "/about",
          user_id: 456,
          timestamp: ~N[2021-01-01 00:10:30],
          engagement_time: 30_000
        )
      ])

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["is", "event:page", ["/"]]],
          metrics: @detailed_metrics
        )

      assert response["results"] == [
               %{"dimensions" => ["/"], "metrics" => [2, 3, 50, 90, 0, 100.0]}
             ]
    end

    test "calculates scroll_depth", %{conn: conn, site: site} do
      t0 = ~N[2020-01-01 00:00:00]
      [t1, t2, t3] = for i <- 1..3, do: NaiveDateTime.add(t0, i, :minute)

      populate_stats(site, [
        build(:pageview, user_id: 12, pathname: "/blog", timestamp: t0),
        build(:engagement,
          user_id: 12,
          pathname: "/blog",
          timestamp: t1,
          scroll_depth: 20,
          engagement_time: 60_000
        ),
        build(:pageview, user_id: 12, pathname: "/another", timestamp: t1),
        build(:engagement,
          user_id: 12,
          pathname: "/another",
          timestamp: t2,
          scroll_depth: 24,
          engagement_time: 60_000
        ),
        build(:pageview, user_id: 34, pathname: "/blog", timestamp: t0),
        build(:engagement,
          user_id: 34,
          pathname: "/blog",
          timestamp: t1,
          scroll_depth: 17,
          engagement_time: 60_000
        ),
        build(:pageview, user_id: 34, pathname: "/another", timestamp: t1),
        build(:engagement,
          user_id: 34,
          pathname: "/another",
          timestamp: t2,
          scroll_depth: 26,
          engagement_time: 60_000
        ),
        build(:pageview, user_id: 34, pathname: "/blog", timestamp: t2),
        build(:engagement,
          user_id: 34,
          pathname: "/blog",
          timestamp: t3,
          scroll_depth: 60,
          engagement_time: 60_000
        ),
        build(:pageview, user_id: 56, pathname: "/blog", timestamp: t0),
        build(:engagement,
          user_id: 56,
          pathname: "/blog",
          timestamp: t1,
          scroll_depth: 100,
          engagement_time: 60_000
        )
      ])

      response =
        query_pages(conn, site,
          date_range: ["2020-01-01", "2020-01-01"],
          metrics: @detailed_metrics,
          order_by: [["scroll_depth", "asc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["/another"], "metrics" => [2, 2, 0, 60, 25, 66.67]},
               %{"dimensions" => ["/blog"], "metrics" => [3, 4, 33, 80, 60, 100.0]}
             ]
    end

    test "calculates scroll_depth from native and imported data combined", %{
      conn: conn,
      site: site,
      site_import: site_import
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: @user_id,
          pathname: "/blog",
          timestamp: ~N[2020-01-01 00:00:00]
        ),
        build(:engagement,
          user_id: @user_id,
          pathname: "/blog",
          timestamp: ~N[2020-01-01 00:00:00],
          scroll_depth: 80,
          engagement_time: 20_000
        ),
        build(:imported_pages,
          date: ~D[2020-01-01],
          visitors: 3,
          pageviews: 3,
          total_time_on_page: 90,
          total_time_on_page_visits: 3,
          page: "/blog",
          total_scroll_depth: 120,
          total_scroll_depth_visits: 3
        )
      ])

      populate_stats(site, site_import.id, [
        build(:imported_visitors, date: ~D[2020-01-01]),
        build(:imported_visitors, date: ~D[2020-01-01]),
        build(:imported_visitors, date: ~D[2020-01-01])
      ])

      response =
        query_pages(conn, site,
          date_range: ["2020-01-01", "2020-01-01"],
          metrics: @detailed_metrics,
          include: %{"imports" => true},
          order_by: [["scroll_depth", "desc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["/blog"], "metrics" => [4, 4, 100, 28, 50, 100.0]}
             ]
    end

    test "handles missing scroll_depth data from native and imported sources", %{
      conn: conn,
      site: site,
      site_import: site_import
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
          scroll_depth: 80,
          engagement_time: 60_000
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
          scroll_depth: 40,
          engagement_time: 60_000
        ),
        build(:imported_pages,
          date: ~D[2020-01-01],
          visitors: 4,
          pageviews: 4,
          total_time_on_page: 180,
          total_time_on_page_visits: 4,
          page: "/native-and-imported",
          total_scroll_depth: 120,
          total_scroll_depth_visits: 3
        ),
        build(:imported_pages,
          date: ~D[2020-01-01],
          visitors: 20,
          pageviews: 30,
          total_time_on_page: 300,
          total_time_on_page_visits: 10,
          page: "/imported-only",
          total_scroll_depth: 100,
          total_scroll_depth_visits: 10
        )
      ])

      populate_stats(
        site,
        site_import.id,
        for(_ <- 1..24, do: build(:imported_visitors, date: ~D[2020-01-01]))
      )

      response =
        query_pages(conn, site,
          date_range: ["2020-01-01", "2020-01-01"],
          metrics: @detailed_metrics,
          include: %{"imports" => true},
          order_by: [["scroll_depth", "desc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["/native-and-imported"], "metrics" => [5, 5, 0, 48, 50, 20.0]},
               %{"dimensions" => ["/native-only"], "metrics" => [1, 1, 0, 60, 40, 4.0]},
               %{"dimensions" => ["/imported-only"], "metrics" => [20, 30, 0, 30, 10, 80.0]}
             ]
    end

    test "can query scroll depth and time-on-page only from imported data, ignoring rows where scroll depth doesn't exist",
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
          total_scroll_depth: 100,
          total_scroll_depth_visits: 10,
          total_time_on_page: 300,
          total_time_on_page_visits: 5
        ),
        build(:imported_pages,
          date: ~D[2020-01-01],
          visitors: 100,
          pageviews: 150,
          page: "/blog",
          total_scroll_depth: 0,
          total_scroll_depth_visits: 0,
          total_time_on_page: 0,
          total_time_on_page_visits: 0
        )
      ])

      response =
        query_pages(conn, site,
          date_range: "7d",
          relative_date: "2020-01-02",
          metrics: @detailed_metrics,
          include: %{"imports" => true}
        )

      assert response["results"] == [
               %{"dimensions" => ["/blog"], "metrics" => [110, 160, 0, 60, 10, nil]}
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
        build(:engagement,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00],
          engagement_time: 60_000
        ),
        build(:pageview,
          pathname: "/irrelevant",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:engagement,
          pathname: "/irrelevant",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:02:00],
          engagement_time: 60_000
        ),
        build(:pageview,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        build(:engagement,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:02:30],
          engagement_time: 30_000
        ),
        build(:pageview,
          pathname: "/",
          user_id: 123,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:engagement,
          pathname: "/",
          user_id: 123,
          timestamp: ~N[2021-01-01 00:01:00],
          engagement_time: 60_000
        ),
        build(:pageview,
          pathname: "/about",
          user_id: 456,
          timestamp: ~N[2021-01-01 00:10:00]
        ),
        build(:engagement,
          pathname: "/about",
          user_id: 456,
          timestamp: ~N[2021-01-01 00:10:30],
          engagement_time: 30_000
        )
      ])

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["is", "event:page", ["/", "/about"]]],
          metrics: @detailed_metrics
        )

      assert response["results"] == [
               %{"dimensions" => ["/"], "metrics" => [2, 3, 50, 75, 0, 66.67]},
               %{"dimensions" => ["/about"], "metrics" => [1, 1, 100, 30, 0, 33.33]}
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
        build(:engagement,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00],
          engagement_time: 60_000
        ),
        build(:pageview,
          pathname: "/irrelevant",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:engagement,
          pathname: "/irrelevant",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:02:00],
          engagement_time: 60_000
        ),
        build(:pageview,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        build(:engagement,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:02:30],
          engagement_time: 30_000
        ),
        build(:pageview,
          pathname: "/",
          user_id: 123,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:engagement,
          pathname: "/",
          user_id: 123,
          timestamp: ~N[2021-01-01 00:01:00],
          engagement_time: 60_000
        ),
        build(:pageview,
          pathname: "/about",
          user_id: 456,
          timestamp: ~N[2021-01-01 00:10:00]
        ),
        build(:engagement,
          pathname: "/about",
          user_id: 456,
          timestamp: ~N[2021-01-01 00:10:30],
          engagement_time: 30_000
        )
      ])

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["is_not", "event:page", ["/irrelevant", "/about"]]],
          metrics: @detailed_metrics
        )

      assert response["results"] == [
               %{"dimensions" => ["/"], "metrics" => [2, 3, 50, 75, 0, 100.0]}
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
        build(:engagement,
          pathname: "/blog/post-1",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00],
          engagement_time: 60_000
        ),
        build(:pageview,
          pathname: "/blog/post-2",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:engagement,
          pathname: "/blog/post-2",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:30],
          engagement_time: 30_000
        ),
        build(:pageview,
          pathname: "/",
          user_id: 100,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:engagement,
          pathname: "/",
          user_id: 100,
          timestamp: ~N[2021-01-01 00:00:30],
          engagement_time: 30_000
        ),
        build(:pageview,
          pathname: "/articles/post-1",
          user_id: 200,
          timestamp: ~N[2021-01-01 00:10:00]
        ),
        build(:engagement,
          pathname: "/articles/post-1",
          user_id: 200,
          timestamp: ~N[2021-01-01 00:10:30],
          engagement_time: 30_000
        ),
        build(:pageview,
          pathname: "/articles/post-1",
          user_id: 300,
          timestamp: ~N[2021-01-01 00:10:00]
        ),
        build(:engagement,
          pathname: "/articles/post-1",
          user_id: 300,
          timestamp: ~N[2021-01-01 00:10:30],
          engagement_time: 30_000
        )
      ])

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["contains", "event:page", ["/blog/", "/articles/"]]],
          metrics: @detailed_metrics,
          order_by: [["visitors", "desc"], ["event:page", "asc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["/articles/post-1"], "metrics" => [2, 2, 100, 30, 0, 66.67]},
               %{"dimensions" => ["/blog/post-1"], "metrics" => [1, 1, 0, 60, 0, 33.33]},
               %{"dimensions" => ["/blog/post-2"], "metrics" => [1, 1, 0, 30, 0, 33.33]}
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
        build(:engagement,
          pathname: "/blog/(/post-1",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00],
          engagement_time: 60_000
        ),
        build(:pageview,
          pathname: "/blog/(/post-2",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:engagement,
          pathname: "/blog/(/post-2",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:30],
          engagement_time: 30_000
        ),
        build(:pageview,
          pathname: "/",
          user_id: 456,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:engagement,
          pathname: "/",
          user_id: 456,
          timestamp: ~N[2021-01-01 00:00:30],
          engagement_time: 30_000
        )
      ])

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["contains", "event:page", ["/blog/(/", "/blog/)/"]]],
          order_by: [["visitors", "desc"], ["event:page", "asc"]],
          metrics: @detailed_metrics
        )

      assert response["results"] == [
               %{"dimensions" => ["/blog/(/post-1"], "metrics" => [1, 1, 0, 60, 0, 100.0]},
               %{"dimensions" => ["/blog/(/post-2"], "metrics" => [1, 1, 0, 30, 0, 100.0]}
             ]
    end

    test "can filter using the not_matches_member filter type",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/blog/post-1",
          user_id: 100,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:engagement,
          pathname: "/blog/post-1",
          user_id: 100,
          timestamp: ~N[2021-01-01 00:00:30],
          engagement_time: 30_000
        ),
        build(:pageview,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:engagement,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:10:00],
          engagement_time: 600_000
        ),
        build(:pageview,
          pathname: "/about",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:10:00]
        ),
        build(:engagement,
          pathname: "/about",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:10:30],
          engagement_time: 30_000
        ),
        build(:pageview,
          pathname: "/",
          user_id: 200,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:engagement,
          pathname: "/",
          user_id: 200,
          timestamp: ~N[2021-01-01 00:10:00],
          engagement_time: 600_000
        ),
        build(:pageview,
          pathname: "/articles/post-1",
          user_id: 300,
          timestamp: ~N[2021-01-01 00:10:00]
        ),
        build(:engagement,
          pathname: "/articles/post-1",
          user_id: 300,
          timestamp: ~N[2021-01-01 00:10:30],
          engagement_time: 30_000
        )
      ])

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["contains_not", "event:page", ["/blog/", "/articles/"]]],
          metrics: @detailed_metrics
        )

      assert response["results"] == [
               %{"dimensions" => ["/"], "metrics" => [2, 2, 50, 600, 0, 100.0]},
               %{"dimensions" => ["/about"], "metrics" => [1, 1, 0, 30, 0, 50.0]}
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

      response = query_pages(conn, site, date_range: "day")

      assert response["results"] == [
               %{"dimensions" => ["/"], "metrics" => [3, 50.0]},
               %{"dimensions" => ["/register"], "metrics" => [2, 33.33]},
               %{"dimensions" => ["/contact"], "metrics" => [1, 16.67]}
             ]

      response = query_pages(conn, site, date_range: "day", include: %{"imports" => true})

      assert response["results"] == [
               %{"dimensions" => ["/"], "metrics" => [4, 66.67]},
               %{"dimensions" => ["/register"], "metrics" => [3, 50.0]},
               %{"dimensions" => ["/contact"], "metrics" => [1, 16.67]}
             ]
    end

    test "returns scroll depth warning code", %{conn: conn, site: site} do
      response =
        query_pages(conn, site,
          date_range: "day",
          metrics: @detailed_metrics,
          include: %{"imports" => true}
        )

      assert response["meta"]["metric_warnings"]["scroll_depth"]["code"] ==
               "no_imported_scroll_depth"
    end

    test "returns imported pages with a pageview goal filter", %{conn: conn, site: site} do
      insert(:goal, site: site, page_path: "/blog**")

      populate_stats(site, [
        build(:imported_pages, page: "/blog"),
        build(:imported_pages, page: "/not-this"),
        build(:imported_pages, page: "/blog/post-1", visitors: 2),
        build(:imported_visitors, visitors: 4)
      ])

      response =
        query_pages(conn, site,
          date_range: "day",
          filters: [["is", "event:goal", ["Visit /blog**"]]],
          metrics: @goal_filter_metrics,
          include: %{"imports" => true}
        )

      assert response["results"] == [
               %{"dimensions" => ["/blog/post-1"], "metrics" => [2, 100.0, 2]},
               %{"dimensions" => ["/blog"], "metrics" => [1, 100.0, 1]}
             ]
    end

    test "calculates bounce rate and time on page for pages", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:engagement,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00],
          engagement_time: 900_000
        ),
        build(:pageview,
          pathname: "/some-other-page",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:engagement,
          pathname: "/some-other-page",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:30],
          engagement_time: 30_000
        ),
        build(:pageview,
          pathname: "/",
          user_id: 123,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:engagement,
          pathname: "/",
          user_id: 123,
          timestamp: ~N[2021-01-01 00:15:30],
          engagement_time: 30_000
        )
      ])

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          metrics: @detailed_metrics
        )

      assert response["results"] == [
               %{"dimensions" => ["/"], "metrics" => [2, 2, 50.0, 465.0, 0, 100.0]},
               %{"dimensions" => ["/some-other-page"], "metrics" => [1, 1, 0, 30, 0, 50.0]}
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

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["is", "event:hostname", ["blog.example.com"]]],
          metrics: @detailed_metrics
        )

      assert response["results"] == [
               %{"dimensions" => ["/about"], "metrics" => [2, 2, 50, nil, nil, 100.0]}
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
        build(:engagement,
          pathname: "/about-blog",
          hostname: "blog.example.com",
          user_id: @user_id + 1,
          timestamp: ~N[2021-01-01 00:01:30],
          engagement_time: 30_000
        ),

        # session 2
        build(:pageview,
          pathname: "/about-blog",
          hostname: "blog.example.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:engagement,
          pathname: "/about-blog",
          hostname: "blog.example.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:10:00],
          engagement_time: 540_000
        ),
        build(:pageview,
          pathname: "/about",
          hostname: "example.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:10:00]
        ),
        build(:engagement,
          pathname: "/about",
          hostname: "example.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00],
          engagement_time: 300_000
        ),
        build(:pageview,
          pathname: "/about-blog",
          hostname: "blog.example.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:engagement,
          pathname: "/about-blog",
          hostname: "blog.example.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:20:00],
          engagement_time: 300_000
        ),
        build(:pageview,
          pathname: "/exit-blog",
          hostname: "blog.example.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:20:00]
        ),
        build(:engagement,
          pathname: "/exit-blog",
          hostname: "blog.example.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:22:00],
          engagement_time: 120_000
        ),
        build(:pageview,
          pathname: "/about",
          hostname: "example.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:22:00]
        ),
        build(:engagement,
          pathname: "/about",
          hostname: "example.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00],
          engagement_time: 180_000
        ),
        build(:pageview,
          pathname: "/exit",
          hostname: "example.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:00]
        ),
        build(:engagement,
          pathname: "/exit",
          hostname: "example.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:25:30],
          engagement_time: 30_000
        ),

        # session 3
        build(:pageview,
          pathname: "/about",
          hostname: "example.com",
          user_id: @user_id + 2,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:engagement,
          pathname: "/about",
          hostname: "example.com",
          user_id: @user_id + 2,
          timestamp: ~N[2021-01-01 00:01:30],
          engagement_time: 30_000
        )
      ])

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["is", "event:hostname", ["blog.example.com"]]],
          metrics: @detailed_metrics
        )

      assert response["results"] == [
               %{"dimensions" => ["/about-blog"], "metrics" => [2, 3, 50, 435, 0, 100.0]},
               %{"dimensions" => ["/exit-blog"], "metrics" => [1, 1, 0, 120, 0, 50.0]}
             ]
    end

    test "calculates bounce rate and time on page for pages with imported data", %{
      conn: conn,
      site: site,
      site_import: site_import
    } do
      populate_stats(site, [
        build(:pageview,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:engagement,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00],
          engagement_time: 900_000
        ),
        build(:pageview,
          pathname: "/some-other-page",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:engagement,
          pathname: "/some-other-page",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:30],
          engagement_time: 30_000
        ),
        build(:pageview,
          pathname: "/",
          user_id: 123,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:engagement,
          pathname: "/",
          user_id: 123,
          timestamp: ~N[2021-01-01 00:30:00],
          engagement_time: 900_000
        ),
        build(:imported_pages,
          page: "/",
          date: ~D[2021-01-01],
          total_time_on_page: 700,
          total_time_on_page_visits: 3
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
          total_time_on_page: 60,
          total_time_on_page_visits: 1
        )
      ])

      populate_stats(site, site_import.id, [
        build(:imported_visitors, date: ~D[2021-01-01]),
        build(:imported_visitors, date: ~D[2021-01-01]),
        build(:imported_visitors, date: ~D[2021-01-01])
      ])

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          metrics: @detailed_metrics,
          include: %{"imports" => true}
        )

      assert response["results"] == [
               %{"dimensions" => ["/"], "metrics" => [3, 3, 40.0, 500, 0, 60.0]},
               %{"dimensions" => ["/some-other-page"], "metrics" => [2, 2, 0, 45, 0, 40.0]}
             ]
    end

    test "returns top pages in realtime report", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/page1"),
        build(:pageview, pathname: "/page2"),
        build(:pageview, pathname: "/page1")
      ])

      response = query_pages(conn, site, date_range: "realtime")

      assert response["results"] == [
               %{"dimensions" => ["/page1"], "metrics" => [2, 66.67]},
               %{"dimensions" => ["/page2"], "metrics" => [1, 33.33]}
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

      response =
        query_pages(conn, site,
          date_range: "day",
          filters: [["is", "event:goal", ["Signup"]]],
          metrics: @goal_filter_metrics
        )

      assert response["results"] == [
               %{"dimensions" => ["/"], "metrics" => [1, 33.33, 3]}
             ]
    end

    test "filter by :is page with imported data", %{conn: conn, site: site} do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:pageview, user_id: 1, pathname: "/", timestamp: ~N[2021-01-01 12:00:00]),
        build(:engagement,
          user_id: 1,
          pathname: "/",
          timestamp: ~N[2021-01-01 12:01:00],
          engagement_time: 60_000
        ),
        build(:pageview, user_id: 1, pathname: "/ignored", timestamp: ~N[2021-01-01 12:01:00]),
        build(:engagement,
          user_id: 1,
          pathname: "/ignored",
          timestamp: ~N[2021-01-01 12:02:00],
          engagement_time: 60_000
        ),
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
          total_time_on_page: 300,
          total_time_on_page_visits: 3,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages, page: "/ignored", visitors: 10, date: ~D[2021-01-01])
      ])

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["is", "event:page", ["/"]]],
          metrics: @detailed_metrics,
          include: %{"imports" => true}
        )

      assert response["results"] == [
               %{"dimensions" => ["/"], "metrics" => [4, 4, 50, 90.0, 0, 100.0]}
             ]
    end

    test "filter by :member page with imported data", %{conn: conn, site: site} do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:pageview, user_id: 1, pathname: "/", timestamp: ~N[2021-01-01 12:00:00]),
        build(:engagement,
          user_id: 1,
          pathname: "/",
          timestamp: ~N[2021-01-01 12:01:00],
          engagement_time: 60_000
        ),
        build(:pageview, user_id: 1, pathname: "/ignored", timestamp: ~N[2021-01-01 12:01:00]),
        build(:engagement,
          user_id: 1,
          pathname: "/ignored",
          timestamp: ~N[2021-01-01 12:02:00],
          engagement_time: 60_000
        ),
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
          total_time_on_page: 300,
          total_time_on_page_visits: 3,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages,
          page: "/a",
          visitors: 1,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages, page: "/ignored", visitors: 10, date: ~D[2021-01-01])
      ])

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["is", "event:page", ["/", "/a"]]],
          metrics: @detailed_metrics,
          include: %{"imports" => true}
        )

      assert response["results"] == [
               %{"dimensions" => ["/"], "metrics" => [4, 4, 50, 90.0, 0, 80.0]},
               %{"dimensions" => ["/a"], "metrics" => [1, 1, 100, 10.0, nil, 20.0]}
             ]
    end

    test "filter by :matches_wildcard page with imported data", %{conn: conn, site: site} do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:pageview, user_id: 1, pathname: "/aaa", timestamp: ~N[2021-01-01 12:00:00]),
        build(:engagement,
          user_id: 1,
          pathname: "/aaa",
          timestamp: ~N[2021-01-01 12:01:00],
          engagement_time: 60_000
        ),
        build(:pageview, user_id: 1, pathname: "/ignored", timestamp: ~N[2021-01-01 12:01:00]),
        build(:engagement,
          user_id: 1,
          pathname: "/ignored",
          timestamp: ~N[2021-01-01 12:02:00],
          engagement_time: 60_000
        ),
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
          total_time_on_page: 300,
          total_time_on_page_visits: 3,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages,
          page: "/a",
          visitors: 1,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages, page: "/ignored", visitors: 10, date: ~D[2021-01-01])
      ])

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["contains", "event:page", ["/a"]]],
          metrics: @detailed_metrics,
          include: %{"imports" => true}
        )

      assert response["results"] == [
               %{"dimensions" => ["/aaa"], "metrics" => [4, 4, 50.0, 90, 0, 80.0]},
               %{"dimensions" => ["/a"], "metrics" => [1, 1, 100.0, 10, nil, 20.0]}
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

      response =
        query_pages(conn, site,
          date_range: ["2021-01-02", "2021-01-02"],
          metrics: @detailed_metrics,
          include: %{"compare" => "previous_period"}
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["/page2"],
                 "metrics" => [2, 2, 100, nil, nil, 66.67],
                 "comparison" => %{
                   "dimensions" => ["/page2"],
                   "metrics" => [0, 0, 0.0, nil, nil, 0.0],
                   "change" => [100, 100, nil, nil, nil, 100]
                 }
               },
               %{
                 "dimensions" => ["/page1"],
                 "metrics" => [1, 1, 100, nil, nil, 33.33],
                 "comparison" => %{
                   "dimensions" => ["/page1"],
                   "metrics" => [1, 1, 100, nil, nil, 100.0],
                   "change" => [0, 0, 0, nil, nil, -67]
                 }
               }
             ]

      assert %{
               "comparison_date_range" => ["2021-01-01T00:00:00Z", "2021-01-01T23:59:59Z"],
               "date_range" => ["2021-01-02T00:00:00Z", "2021-01-02T23:59:59Z"]
             } = response["query"]
    end

    on_ee do
      test "returns pages across all sites on a consolidated view", %{conn: conn, site: site} do
        another_site = new_site(team: site.team)
        cv = new_consolidated_view(site.team)

        populate_stats(site, [
          build(:pageview, pathname: "/a1", timestamp: ~N[2021-01-01 00:00:00]),
          build(:pageview, pathname: "/a2", timestamp: ~N[2021-01-01 00:00:00]),
          build(:pageview, pathname: "/a2", timestamp: ~N[2021-01-01 00:00:00])
        ])

        populate_stats(another_site, [
          build(:pageview, pathname: "/b1", timestamp: ~N[2021-01-01 00:00:00]),
          build(:pageview, pathname: "/b1", timestamp: ~N[2021-01-01 00:00:00]),
          build(:pageview, pathname: "/b1", timestamp: ~N[2021-01-01 00:00:00])
        ])

        response =
          query_pages(conn, cv,
            date_range: ["2021-01-01", "2021-01-01"],
            metrics: @detailed_metrics
          )

        assert response["results"] == [
                 %{"dimensions" => ["/b1"], "metrics" => [3, 3, 100, nil, nil, 50.0]},
                 %{"dimensions" => ["/a2"], "metrics" => [2, 2, 100, nil, nil, 33.33]},
                 %{"dimensions" => ["/a1"], "metrics" => [1, 1, 100, nil, nil, 16.67]}
               ]
      end
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

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          dimensions: ["visit:entry_page"],
          metrics: ["visitors", "visits", "bounce_rate", "visit_duration", "percentage"]
        )

      assert response["results"] == [
               %{"dimensions" => ["/page1"], "metrics" => [2, 2, 100, 0, 66.67]},
               %{"dimensions" => ["/page2"], "metrics" => [1, 2, 50, 450, 33.33]}
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

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          dimensions: ["visit:entry_page"],
          filters: [["is", "event:props:author", ["John Doe"]]],
          metrics: ["visitors", "visits", "bounce_rate", "visit_duration", "percentage"]
        )

      assert response["results"] == [
               %{"dimensions" => ["/blog"], "metrics" => [1, 1, 0, 60, 50.0]},
               %{"dimensions" => ["/blog/john-2"], "metrics" => [1, 1, 100, 0, 50.0]}
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
        build(:imported_visitors,
          date: ~D[2021-01-01],
          visitors: 2
        ),
        build(:imported_entry_pages,
          entry_page: "/page2",
          date: ~D[2021-01-01],
          entrances: 3,
          visitors: 2,
          visit_duration: 300
        )
      ])

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          dimensions: ["visit:entry_page"],
          metrics: ["visitors", "visits", "bounce_rate", "visit_duration", "percentage"]
        )

      assert response["results"] == [
               %{"dimensions" => ["/page1"], "metrics" => [2, 2, 100, 0, 66.67]},
               %{"dimensions" => ["/page2"], "metrics" => [1, 2, 50, 450, 33.33]}
             ]

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          dimensions: ["visit:entry_page"],
          metrics: ["visitors", "visits", "bounce_rate", "visit_duration", "percentage"],
          include: %{"imports" => true}
        )

      assert response["results"] == [
               %{"dimensions" => ["/page2"], "metrics" => [3, 5, 20.0, 240.0, 60.0]},
               %{"dimensions" => ["/page1"], "metrics" => [2, 2, 100.0, 0.0, 40.0]}
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

      # We're going to only join sessions where the exit hostname matches the filter
      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          dimensions: ["visit:entry_page"],
          filters: [["is", "event:hostname", ["es.example.com"]]],
          metrics: ["visitors", "visits", "bounce_rate", "visit_duration", "percentage"],
          order_by: [["visitors", "desc"], ["visit:entry_page", "asc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["/page1"], "metrics" => [1, 1, 100, 0, 50.0]},
               %{"dimensions" => ["/page2"], "metrics" => [1, 1, 100, 0, 50.0]}
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
        conn
        |> query_pages(site,
          metrics: ["visitors"],
          pagination: %{
            "offset" => Keyword.fetch!(opts, :offset),
            "limit" => Keyword.fetch!(opts, :limit)
          },
          filters: [["is", "event:goal", ["Signup"]]],
          order_by: [["event:page", "asc"]]
        )
        |> Map.get("results")
        |> Enum.map(fn %{"dimensions" => ["/signup/" <> seq]} ->
          seq
        end)
      end

      assert List.first(request.(conn, offset: 0, limit: 100)) == "01"
      assert List.last(request.(conn, offset: 0, limit: 100)) == "30"
      assert List.last(request.(conn, offset: 0, limit: 29)) == "29"
      assert ["01", "02"] = request.(conn, offset: 0, limit: 2)
      assert ["03", "04"] = request.(conn, offset: 2, limit: 2)
      assert ["01", "02", "03", "04", "05"] = request.(conn, offset: 0, limit: 5)
      assert ["06", "07", "08", "09", "10"] = request.(conn, offset: 5, limit: 5)
      assert ["11", "12", "13", "14", "15"] = request.(conn, offset: 10, limit: 5)
      assert ["20"] = request.(conn, offset: 19, limit: 1)
      assert [] = request.(conn, offset: 30, limit: 1)
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

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          dimensions: ["visit:entry_page"],
          filters: [["is", "event:goal", ["Signup"]]],
          metrics: ["visitors", "group_conversion_rate", "total_visitors"],
          order_by: [["visitors", "desc"], ["visit:entry_page", "asc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["/page1"], "metrics" => [1, 50.0, 2]},
               %{"dimensions" => ["/page2"], "metrics" => [1, 100.0, 1]}
             ]
    end

    test "can filter out empty entry pages (sessions with only custom events)", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Signup",
          timestamp: ~N[2021-01-01 00:15:00],
          pathname: "/"
        )
      ])

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          dimensions: ["visit:entry_page"],
          filters: [["is_not", "visit:entry_page", [""]]],
          metrics: ["visitors", "visits", "bounce_rate", "visit_duration", "percentage"]
        )

      assert response["results"] == []
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

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          dimensions: ["visit:entry_page"],
          filters: [["contains", "visit:entry_page", ["/a", "/b"]]],
          metrics: ["visitors", "visits", "bounce_rate", "visit_duration", "percentage"],
          include: %{"imports" => true}
        )

      assert response["results"] == [
               %{"dimensions" => ["/a"], "metrics" => [6, 10, 10.0, 100.0, 66.67]},
               %{"dimensions" => ["/bbb"], "metrics" => [2, 2, 0.0, 50.0, 22.22]},
               %{"dimensions" => ["/aaa"], "metrics" => [1, 1, 100.0, 0, 11.11]}
             ]
    end

    test "returns entry pages broken down by entry page hostname and page",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/landing",
          hostname: "blog.example.com",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/about",
          hostname: "blog.example.com",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:05:00]
        ),
        build(:pageview,
          pathname: "/landing",
          hostname: "blog.example.com",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/landing",
          hostname: "www.example.com",
          user_id: 3,
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          dimensions: ["visit:entry_page_hostname", "visit:entry_page"],
          metrics: ["visitors", "visits", "bounce_rate", "percentage"],
          filters: [["is_not", "visit:entry_page", [""]]],
          order_by: [["visitors", "desc"], ["visit:entry_page_hostname", "asc"]]
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["blog.example.com", "/landing"],
                 "metrics" => [2, 2, 50, 66.67]
               },
               %{
                 "dimensions" => ["www.example.com", "/landing"],
                 "metrics" => [1, 1, 100, 33.33]
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

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          dimensions: ["visit:exit_page"],
          metrics: ["visitors", "visits", "exit_rate", "percentage"]
        )

      assert response["results"] == [
               %{"dimensions" => ["/page1"], "metrics" => [2, 2, 66.7, 66.67]},
               %{"dimensions" => ["/page2"], "metrics" => [1, 1, 100, 33.33]}
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

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          dimensions: ["visit:exit_page"],
          metrics: ["visitors", "visits", "exit_rate", "percentage"],
          order_by: [["visits", "asc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["/page2"], "metrics" => [1, 1, 100.0, 33.33]},
               %{"dimensions" => ["/page1"], "metrics" => [2, 2, 66.7, 66.67]}
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

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          dimensions: ["visit:exit_page"],
          filters: [["is", "event:hostname", ["es.example.com"]]],
          metrics: ["visitors", "visits", "percentage"]
        )

      # We're going to only join sessions where the entry hostname matches the filter
      assert response["results"] == [
               %{"dimensions" => ["/page1"], "metrics" => [1, 1, 100.0]}
             ]
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

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          dimensions: ["visit:exit_page"],
          filters: [["is", "event:props:author", ["John Doe"]]],
          metrics: ["visitors", "visits", "percentage"]
        )

      assert response["results"] == [
               %{"dimensions" => ["/"], "metrics" => [1, 1, 100.0]}
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

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          dimensions: ["visit:exit_page"],
          filters: [["is_not", "visit:exit_page", [""]]],
          metrics: ["visitors", "visits", "exit_rate", "percentage"]
        )

      assert response["results"] == [
               %{"dimensions" => ["/page1"], "metrics" => [2, 2, 66.7, 66.67]},
               %{"dimensions" => ["/page2"], "metrics" => [1, 1, 100.0, 33.33]}
             ]

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          dimensions: ["visit:exit_page"],
          filters: [["is_not", "visit:exit_page", [""]]],
          metrics: ["visitors", "visits", "exit_rate", "percentage"],
          include: %{"imports" => true}
        )

      assert response["results"] == [
               %{"dimensions" => ["/page2"], "metrics" => [3, 4, 80.0, 60.0]},
               %{"dimensions" => ["/page1"], "metrics" => [2, 2, 66.7, 40.0]}
             ]
    end

    test "returns top exit pages when filtering for goal", %{
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

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          dimensions: ["visit:exit_page"],
          filters: [["is", "event:goal", ["Signup"]]],
          metrics: ["visitors", "group_conversion_rate", "total_visitors"],
          order_by: [["visitors", "desc"], ["visit:exit_page", "asc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["/exit1"], "metrics" => [1, 100.0, 1]},
               %{"dimensions" => ["/exit2"], "metrics" => [1, 100.0, 1]}
             ]
    end

    test "returns top exit pages when filtering for page", %{conn: conn, site: site} do
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

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          dimensions: ["visit:exit_page"],
          filters: [["is", "event:page", ["/exit1"]]],
          metrics: ["visitors", "visits", "percentage"]
        )

      assert response["results"] == [
               %{"dimensions" => ["/exit1"], "metrics" => [1, 1, 50.0]},
               %{"dimensions" => ["/exit2"], "metrics" => [1, 1, 50.0]}
             ]
    end

    test "can filter out empty exit pages (sessions with only custom events)", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Signup",
          timestamp: ~N[2021-01-01 00:15:00],
          pathname: "/"
        )
      ])

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          dimensions: ["visit:exit_page"],
          filters: [["is_not", "visit:exit_page", [""]]],
          metrics: ["visitors", "visits", "exit_rate", "percentage"]
        )

      assert response["results"] == []
    end

    test "returns exit pages broken down by exit page hostname and page with exit_rate",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/about",
          hostname: "blog.example.com",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/about",
          hostname: "blog.example.com",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/about",
          hostname: "www.example.com",
          user_id: 3,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/docs",
          hostname: "www.example.com",
          user_id: 3,
          timestamp: ~N[2021-01-01 00:05:00]
        )
      ])

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          dimensions: ["visit:exit_page_hostname", "visit:exit_page"],
          metrics: ["visitors", "visits", "exit_rate", "percentage"],
          filters: [["is_not", "visit:exit_page", [""]]],
          order_by: [["visitors", "desc"], ["visit:exit_page_hostname", "asc"]]
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["blog.example.com", "/about"],
                 "metrics" => [2, 2, 66.7, 66.67]
               },
               %{
                 "dimensions" => ["www.example.com", "/docs"],
                 "metrics" => [1, 1, 100.0, 33.33]
               }
             ]
    end

    test "exit_rate works with exit page hostname and page dimensions in either order",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/about",
          hostname: "blog.example.com",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/about",
          hostname: "blog.example.com",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      for dimensions <- [
            ["visit:exit_page_hostname", "visit:exit_page"],
            ["visit:exit_page", "visit:exit_page_hostname"]
          ] do
        response =
          query_pages(conn, site,
            date_range: ["2021-01-01", "2021-01-01"],
            dimensions: dimensions,
            metrics: ["visitors", "exit_rate"],
            filters: [["is_not", "visit:exit_page", [""]]]
          )

        assert response["results"] != [],
               "expected results for dimensions #{inspect(dimensions)}"

        assert Enum.all?(response["results"], fn r -> not is_nil(r["metrics"]) end),
               "expected no errors for dimensions #{inspect(dimensions)}"
      end
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

      response =
        query_pages(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          dimensions: ["visit:exit_page"],
          filters: [["is_not", "visit:exit_page", ["/ignored"]]],
          metrics: ["visitors", "visits", "exit_rate", "percentage"],
          include: %{"imports" => true}
        )

      assert response["results"] == [
               %{"dimensions" => ["/a"], "metrics" => [6, 10, 50.0, 66.67]},
               %{"dimensions" => ["/bbb"], "metrics" => [2, 2, 100.0, 22.22]},
               %{"dimensions" => ["/aaa"], "metrics" => [1, 1, 100.0, 11.11]}
             ]
    end

    @tag :ee_only
    test "return revenue metrics for entry pages breakdown", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, pathname: "/first"),
        build(:event,
          name: "Payment",
          user_id: 1,
          revenue_reporting_amount: Decimal.new("2000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 2, pathname: "/second"),
        build(:event,
          user_id: 2,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("3000"),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment",
          user_id: 2,
          revenue_reporting_amount: Decimal.new("4000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 3, pathname: "/first"),
        build(:event,
          name: "Payment",
          user_id: 3,
          revenue_reporting_amount: Decimal.new("1000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 4, pathname: "/third"),
        build(:event,
          name: "Payment",
          user_id: 4,
          revenue_reporting_amount: Decimal.new("2500"),
          revenue_reporting_currency: "USD"
        ),
        build(:event, name: "Payment", revenue_reporting_amount: nil),
        build(:event, name: "Payment", revenue_reporting_amount: nil)
      ])

      insert(:goal, %{site: site, event_name: "Payment", currency: :USD})

      response =
        query_pages(conn, site,
          date_range: "day",
          dimensions: ["visit:entry_page"],
          filters: [["is", "event:goal", ["Payment"]], ["is_not", "visit:entry_page", [""]]],
          metrics: [
            "visitors",
            "group_conversion_rate",
            "total_visitors",
            "average_revenue",
            "total_revenue"
          ],
          order_by: [["visitors", "desc"], ["visit:entry_page", "asc"]]
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["/first"],
                 "metrics" => [
                   2,
                   100.0,
                   2,
                   %{
                     "currency" => "USD",
                     "long" => "$1,500.00",
                     "short" => "$1.5K",
                     "value" => 1500.0
                   },
                   %{
                     "currency" => "USD",
                     "long" => "$3,000.00",
                     "short" => "$3.0K",
                     "value" => 3000.0
                   }
                 ]
               },
               %{
                 "dimensions" => ["/second"],
                 "metrics" => [
                   1,
                   100.0,
                   1,
                   %{
                     "currency" => "USD",
                     "long" => "$3,500.00",
                     "short" => "$3.5K",
                     "value" => 3500.0
                   },
                   %{
                     "currency" => "USD",
                     "long" => "$7,000.00",
                     "short" => "$7.0K",
                     "value" => 7000.0
                   }
                 ]
               },
               %{
                 "dimensions" => ["/third"],
                 "metrics" => [
                   1,
                   100.0,
                   1,
                   %{
                     "currency" => "USD",
                     "long" => "$2,500.00",
                     "short" => "$2.5K",
                     "value" => 2500.0
                   },
                   %{
                     "currency" => "USD",
                     "long" => "$2,500.00",
                     "short" => "$2.5K",
                     "value" => 2500.0
                   }
                 ]
               }
             ]
    end

    @tag :ee_only
    test "return revenue metrics for exit pages breakdown", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, pathname: "/first"),
        build(:event,
          name: "Payment",
          user_id: 1,
          revenue_reporting_amount: Decimal.new("2000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 1, pathname: "/exit_first"),
        build(:pageview, user_id: 2, pathname: "/second"),
        build(:event,
          user_id: 2,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("3000"),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment",
          user_id: 2,
          revenue_reporting_amount: Decimal.new("4000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 2, pathname: "/exit_second"),
        build(:pageview, user_id: 3, pathname: "/first"),
        build(:event,
          name: "Payment",
          user_id: 3,
          revenue_reporting_amount: Decimal.new("1000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 3, pathname: "/exit_first"),
        build(:pageview, user_id: 4, pathname: "/third"),
        build(:event,
          name: "Payment",
          user_id: 4,
          revenue_reporting_amount: Decimal.new("2500"),
          revenue_reporting_currency: "USD"
        ),
        build(:event, name: "Payment", revenue_reporting_amount: nil),
        build(:event, name: "Payment", revenue_reporting_amount: nil)
      ])

      insert(:goal, %{site: site, event_name: "Payment", currency: :USD})

      response =
        query_pages(conn, site,
          date_range: "day",
          dimensions: ["visit:exit_page"],
          filters: [["is", "event:goal", ["Payment"]], ["is_not", "visit:exit_page", [""]]],
          metrics: [
            "visitors",
            "group_conversion_rate",
            "total_visitors",
            "average_revenue",
            "total_revenue"
          ],
          order_by: [["visitors", "desc"], ["visit:exit_page", "asc"]]
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["/exit_first"],
                 "metrics" => [
                   2,
                   100.0,
                   2,
                   %{
                     "currency" => "USD",
                     "long" => "$1,500.00",
                     "short" => "$1.5K",
                     "value" => 1500.0
                   },
                   %{
                     "currency" => "USD",
                     "long" => "$3,000.00",
                     "short" => "$3.0K",
                     "value" => 3000.0
                   }
                 ]
               },
               %{
                 "dimensions" => ["/exit_second"],
                 "metrics" => [
                   1,
                   100.0,
                   1,
                   %{
                     "currency" => "USD",
                     "long" => "$3,500.00",
                     "short" => "$3.5K",
                     "value" => 3500.0
                   },
                   %{
                     "currency" => "USD",
                     "long" => "$7,000.00",
                     "short" => "$7.0K",
                     "value" => 7000.0
                   }
                 ]
               },
               %{
                 "dimensions" => ["/third"],
                 "metrics" => [
                   1,
                   100.0,
                   1,
                   %{
                     "currency" => "USD",
                     "long" => "$2,500.00",
                     "short" => "$2.5K",
                     "value" => 2500.0
                   },
                   %{
                     "currency" => "USD",
                     "long" => "$2,500.00",
                     "short" => "$2.5K",
                     "value" => 2500.0
                   }
                 ]
               }
             ]
    end

    @tag :ee_only
    test "return revenue metrics for pages breakdown", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, pathname: "/first"),
        build(:event,
          name: "Payment",
          pathname: "/purchase/first",
          user_id: 1,
          revenue_reporting_amount: Decimal.new("2000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 1, pathname: "/exit_first"),
        build(:pageview, user_id: 2, pathname: "/second"),
        build(:event,
          user_id: 2,
          name: "Payment",
          pathname: "/purchase/second",
          revenue_reporting_amount: Decimal.new("3000"),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment",
          pathname: "/purchase/second",
          user_id: 2,
          revenue_reporting_amount: Decimal.new("4000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 2, pathname: "/exit_second"),
        build(:pageview, user_id: 3, pathname: "/first"),
        build(:event,
          name: "Payment",
          pathname: "/purchase/first",
          user_id: 3,
          revenue_reporting_amount: Decimal.new("1000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 3, pathname: "/exit_first"),
        build(:pageview, user_id: 4, pathname: "/third"),
        build(:event,
          name: "Payment",
          pathname: "/purchase/third",
          user_id: 4,
          revenue_reporting_amount: Decimal.new("2500"),
          revenue_reporting_currency: "USD"
        ),
        build(:event, name: "Payment", pathname: "/nopay", revenue_reporting_amount: nil),
        build(:event, name: "Payment", pathname: "/nopay", revenue_reporting_amount: nil),
        build(:event, name: "Payment", pathname: "/nopay", revenue_reporting_amount: nil)
      ])

      insert(:goal, %{site: site, event_name: "Payment", currency: :USD})

      response =
        query_pages(conn, site,
          date_range: "day",
          filters: [["is", "event:goal", ["Payment"]]],
          metrics: [
            "visitors",
            "group_conversion_rate",
            "total_visitors",
            "average_revenue",
            "total_revenue"
          ]
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["/nopay"],
                 "metrics" => [
                   3,
                   100.0,
                   3,
                   %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
                   %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0}
                 ]
               },
               %{
                 "dimensions" => ["/purchase/first"],
                 "metrics" => [
                   2,
                   100.0,
                   2,
                   %{
                     "currency" => "USD",
                     "long" => "$1,500.00",
                     "short" => "$1.5K",
                     "value" => 1500.0
                   },
                   %{
                     "currency" => "USD",
                     "long" => "$3,000.00",
                     "short" => "$3.0K",
                     "value" => 3000.0
                   }
                 ]
               },
               %{
                 "dimensions" => ["/purchase/second"],
                 "metrics" => [
                   1,
                   100.0,
                   1,
                   %{
                     "currency" => "USD",
                     "long" => "$3,500.00",
                     "short" => "$3.5K",
                     "value" => 3500.0
                   },
                   %{
                     "currency" => "USD",
                     "long" => "$7,000.00",
                     "short" => "$7.0K",
                     "value" => 7000.0
                   }
                 ]
               },
               %{
                 "dimensions" => ["/purchase/third"],
                 "metrics" => [
                   1,
                   100.0,
                   1,
                   %{
                     "currency" => "USD",
                     "long" => "$2,500.00",
                     "short" => "$2.5K",
                     "value" => 2500.0
                   },
                   %{
                     "currency" => "USD",
                     "long" => "$2,500.00",
                     "short" => "$2.5K",
                     "value" => 2500.0
                   }
                 ]
               }
             ]
    end
  end
end
