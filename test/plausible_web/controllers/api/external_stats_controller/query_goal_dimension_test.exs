defmodule PlausibleWeb.Api.ExternalStatsController.QueryGoalDimensionTest do
  use PlausibleWeb.ConnCase

  @user_id Enum.random(1000..9999)

  setup [:create_user, :create_site, :create_api_key, :use_api_key]

  describe "breakdown by event:goal" do
    test "returns custom event goals and pageview goals", %{conn: conn, site: site} do
      insert(:goal, %{site: site, event_name: "Purchase"})
      insert(:goal, %{site: site, page_path: "/test"})

      populate_stats(site, [
        build(:pageview,
          timestamp: ~N[2021-01-01 00:00:01],
          pathname: "/test"
        ),
        build(:event,
          name: "Purchase",
          timestamp: ~N[2021-01-01 00:00:03]
        ),
        build(:event,
          name: "Purchase",
          timestamp: ~N[2021-01-01 00:00:03]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors"],
          "dimensions" => ["event:goal"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["Purchase"], "metrics" => [2]},
               %{"dimensions" => ["Visit /test"], "metrics" => [1]}
             ]
    end

    test "returns pageview goals containing wildcards", %{conn: conn, site: site} do
      insert(:goal, %{site: site, page_path: "/**/post"})
      insert(:goal, %{site: site, page_path: "/blog**"})

      populate_stats(site, [
        build(:pageview, pathname: "/blog", user_id: @user_id),
        build(:pageview, pathname: "/blog/post-1", user_id: @user_id),
        build(:pageview, pathname: "/blog/post-2", user_id: @user_id),
        build(:pageview, pathname: "/blog/something/post"),
        build(:pageview, pathname: "/different/page/post")
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "pageviews"],
          "dimensions" => ["event:goal"],
          "order_by" => [["pageviews", "desc"]]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["Visit /blog**"], "metrics" => [2, 4]},
               %{"dimensions" => ["Visit /**/post"], "metrics" => [2, 2]}
             ]
    end

    test "does not return goals that are not configured for the site", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/register"),
        build(:event, name: "Signup")
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "pageviews"],
          "dimensions" => ["event:goal"]
        })

      assert json_response(conn, 200)["results"] == []
    end

    test "returns conversion_rate in an event:goal breakdown", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event, name: "Signup", user_id: 1),
        build(:event, name: "Signup", user_id: 1),
        build(:pageview, pathname: "/blog"),
        build(:pageview, pathname: "/blog/post"),
        build(:pageview)
      ])

      insert(:goal, %{site: site, event_name: "Signup"})
      insert(:goal, %{site: site, page_path: "/blog**"})

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "events", "conversion_rate"],
          "dimensions" => ["event:goal"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["Visit /blog**"], "metrics" => [2, 2, 50.0]},
               %{"dimensions" => ["Signup"], "metrics" => [1, 2, 25.0]}
             ]
    end

    test "returns conversion_rate alone in an event:goal breakdown", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event, name: "Signup", user_id: 1),
        build(:pageview)
      ])

      insert(:goal, %{site: site, event_name: "Signup"})

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["conversion_rate"],
          "dimensions" => ["event:goal"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["Signup"], "metrics" => [50.0]}
             ]
    end
  end

  describe "page scroll goals" do
    test "a scroll depth of 255 (missing) is not considered a conversion (page scroll goal filter)",
         %{
           conn: conn,
           site: site
         } do
      insert(:goal,
        site: site,
        page_path: "/blog",
        scroll_threshold: 90,
        display_name: "Scroll /blog 90"
      )

      populate_stats(site, [
        build(:pageview, user_id: 12, pathname: "/blog", timestamp: ~N[2021-01-01 00:00:00]),
        build(:engagement,
          user_id: 12,
          pathname: "/blog",
          timestamp: ~N[2021-01-01 00:00:00],
          scroll_depth: 255
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "filters" => [["is", "event:goal", ["Scroll /blog 90"]]],
          "date_range" => "all"
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => [], "metrics" => [0]}
             ]
    end

    test "a scroll depth of 255 (missing) is not considered a conversion (page scroll goal breakdown)",
         %{
           conn: conn,
           site: site
         } do
      insert(:goal,
        site: site,
        page_path: "/blog",
        scroll_threshold: 90,
        display_name: "Scroll /blog 90"
      )

      populate_stats(site, [
        build(:pageview, user_id: 12, pathname: "/blog", timestamp: ~N[2021-01-01 00:00:00]),
        build(:engagement,
          user_id: 12,
          pathname: "/blog",
          timestamp: ~N[2021-01-01 00:00:00],
          scroll_depth: 255
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:goal"]
        })

      assert json_response(conn, 200)["results"] == []
    end

    test "returns page scroll goals and pageview goals in breakdown with page filter", %{
      conn: conn,
      site: site
    } do
      insert(:goal, site: site, page_path: "/blog")

      insert(:goal,
        site: site,
        page_path: "/blog",
        scroll_threshold: 25,
        display_name: "Scroll /blog 25"
      )

      populate_stats(site, [
        build(:pageview, user_id: 12, pathname: "/blog", timestamp: ~N[2021-01-01 00:00:00]),
        build(:engagement,
          user_id: 12,
          pathname: "/blog",
          timestamp: ~N[2021-01-01 00:00:00],
          scroll_depth: 10
        ),
        build(:pageview, user_id: 34, pathname: "/blog", timestamp: ~N[2021-01-01 00:00:00]),
        build(:engagement,
          user_id: 34,
          pathname: "/blog",
          timestamp: ~N[2021-01-01 00:00:00],
          scroll_depth: 30
        ),
        build(:pageview)
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "events", "conversion_rate"],
          "filters" => [["is", "event:page", ["/blog"]]],
          "date_range" => "all",
          "dimensions" => ["event:goal"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["Visit /blog"], "metrics" => [2, 2, 100.0]},
               %{"dimensions" => ["Scroll /blog 25"], "metrics" => [1, 0, 50.0]}
             ]
    end

    test "custom props and page scroll goals in a double-dimension breakdown", %{
      conn: conn,
      site: site
    } do
      for threshold <- [25, 50, 75] do
        insert(:goal,
          site: site,
          page_path: "/blog**",
          scroll_threshold: threshold,
          display_name: "Scroll /blog #{threshold}"
        )
      end

      populate_stats(site, [
        build(:pageview,
          pathname: "/blog/john-post",
          "meta.key": ["author"],
          "meta.value": ["john"]
        ),
        build(:pageview,
          user_id: 12,
          pathname: "/blog/john-post",
          timestamp: ~N[2021-01-01 00:00:00],
          "meta.key": ["author"],
          "meta.value": ["john"]
        ),
        build(:engagement,
          user_id: 12,
          pathname: "/blog/john-post",
          timestamp: ~N[2021-01-01 00:00:10],
          scroll_depth: 30,
          "meta.key": ["author"],
          "meta.value": ["john"]
        ),
        build(:pageview,
          user_id: 34,
          pathname: "/blog/jane-post",
          timestamp: ~N[2021-01-01 00:00:00],
          "meta.key": ["author"],
          "meta.value": ["jane"]
        ),
        build(:engagement,
          user_id: 34,
          pathname: "/blog/jane-post",
          timestamp: ~N[2021-01-01 00:00:10],
          scroll_depth: 50,
          "meta.key": ["author"],
          "meta.value": ["jane"]
        ),
        build(:pageview,
          user_id: 56,
          pathname: "/blog/jane-post",
          timestamp: ~N[2021-01-01 00:00:00],
          "meta.key": ["author"],
          "meta.value": ["jane"]
        ),
        build(:engagement,
          user_id: 56,
          pathname: "/blog/jane-post",
          timestamp: ~N[2021-01-01 00:00:10],
          scroll_depth: 75,
          "meta.key": ["author"],
          "meta.value": ["jane"]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "events", "conversion_rate"],
          "date_range" => "all",
          "dimensions" => ["event:goal", "event:props:author"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["Scroll /blog 25", "jane"], "metrics" => [2, 0, 50.0]},
               %{"dimensions" => ["Scroll /blog 50", "jane"], "metrics" => [2, 0, 50.0]},
               %{"dimensions" => ["Scroll /blog 25", "john"], "metrics" => [1, 0, 25.0]},
               %{"dimensions" => ["Scroll /blog 75", "jane"], "metrics" => [1, 0, 25.0]}
             ]
    end

    test "returns group_conversion_rate for a page scroll goal filter in source breakdown", %{
      conn: conn,
      site: site
    } do
      insert(:goal,
        site: site,
        page_path: "/blog",
        scroll_threshold: 50,
        display_name: "Scroll /blog 50"
      )

      populate_stats(site, [
        build(:pageview, referrer_source: "Twitter"),
        build(:pageview,
          user_id: 12,
          pathname: "/blog",
          timestamp: ~N[2021-01-01 00:00:00],
          referrer_source: "Google"
        ),
        build(:engagement,
          user_id: 12,
          pathname: "/blog",
          timestamp: ~N[2021-01-01 00:00:10],
          scroll_depth: 30,
          referrer_source: "Google"
        ),
        build(:pageview,
          user_id: 34,
          pathname: "/blog",
          timestamp: ~N[2021-01-01 00:00:00],
          referrer_source: "Twitter"
        ),
        build(:engagement,
          user_id: 34,
          pathname: "/blog",
          timestamp: ~N[2021-01-01 00:00:10],
          scroll_depth: 50,
          referrer_source: "Twitter"
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "events", "group_conversion_rate"],
          "date_range" => "all",
          "filters" => [["is", "event:goal", ["Scroll /blog 50"]]],
          "dimensions" => ["visit:source"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["Twitter"], "metrics" => [1, 0, 50.0]}
             ]
    end

    test "breakdown by event:props:author with a page scroll goal filter", %{
      conn: conn,
      site: site
    } do
      for threshold <- [25, 50, 75] do
        insert(:goal,
          site: site,
          page_path: "/blog**",
          scroll_threshold: threshold,
          display_name: "Scroll /blog #{threshold}"
        )
      end

      populate_stats(site, [
        build(:pageview,
          pathname: "/blog/john-post",
          "meta.key": ["author"],
          "meta.value": ["john"]
        ),
        build(:pageview,
          user_id: 12,
          pathname: "/blog/john-post",
          timestamp: ~N[2021-01-01 00:00:00],
          "meta.key": ["author"],
          "meta.value": ["john"]
        ),
        build(:engagement,
          user_id: 12,
          pathname: "/blog/john-post",
          timestamp: ~N[2021-01-01 00:00:10],
          scroll_depth: 30,
          "meta.key": ["author"],
          "meta.value": ["john"]
        ),
        build(:pageview,
          user_id: 34,
          pathname: "/blog/jane-post",
          timestamp: ~N[2021-01-01 00:00:00],
          "meta.key": ["author"],
          "meta.value": ["jane"]
        ),
        build(:engagement,
          user_id: 34,
          pathname: "/blog/jane-post",
          timestamp: ~N[2021-01-01 00:00:10],
          scroll_depth: 50,
          "meta.key": ["author"],
          "meta.value": ["jane"]
        ),
        build(:pageview,
          user_id: 56,
          pathname: "/blog/jane-post",
          timestamp: ~N[2021-01-01 00:00:00],
          "meta.key": ["author"],
          "meta.value": ["jane"]
        ),
        build(:engagement,
          user_id: 56,
          pathname: "/blog/jane-post",
          timestamp: ~N[2021-01-01 00:00:10],
          scroll_depth: 75,
          "meta.key": ["author"],
          "meta.value": ["jane"]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "events", "conversion_rate"],
          "date_range" => "all",
          "filters" => [["is", "event:goal", ["Scroll /blog 25"]]],
          "dimensions" => ["event:props:author"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["jane"], "metrics" => [2, 0, 50.0]},
               %{"dimensions" => ["john"], "metrics" => [1, 0, 25.0]}
             ]
    end

    test "breaks down page scroll goals with a custom prop filter", %{
      conn: conn,
      site: site
    } do
      for threshold <- [25, 50, 75] do
        insert(:goal,
          site: site,
          page_path: "/blog**",
          scroll_threshold: threshold,
          display_name: "Scroll /blog #{threshold}"
        )
      end

      populate_stats(site, [
        build(:pageview,
          pathname: "/blog/john-post",
          "meta.key": ["author"],
          "meta.value": ["john"]
        ),
        build(:pageview,
          user_id: 12,
          pathname: "/blog/john-post",
          timestamp: ~N[2021-01-01 00:00:00],
          "meta.key": ["author"],
          "meta.value": ["john"]
        ),
        build(:engagement,
          user_id: 12,
          pathname: "/blog/john-post",
          timestamp: ~N[2021-01-01 00:00:10],
          scroll_depth: 30,
          "meta.key": ["author"],
          "meta.value": ["john"]
        ),
        build(:pageview,
          user_id: 34,
          pathname: "/blog/jane-post",
          timestamp: ~N[2021-01-01 00:00:00],
          "meta.key": ["author"],
          "meta.value": ["jane"]
        ),
        build(:engagement,
          user_id: 34,
          pathname: "/blog/jane-post",
          timestamp: ~N[2021-01-01 00:00:10],
          scroll_depth: 50,
          "meta.key": ["author"],
          "meta.value": ["jane"]
        ),
        build(:pageview,
          user_id: 56,
          pathname: "/blog/jane-post",
          timestamp: ~N[2021-01-01 00:00:00],
          "meta.key": ["author"],
          "meta.value": ["jane"]
        ),
        build(:engagement,
          user_id: 56,
          pathname: "/blog/jane-post",
          timestamp: ~N[2021-01-01 00:00:10],
          scroll_depth: 75,
          "meta.key": ["author"],
          "meta.value": ["jane"]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "events", "conversion_rate"],
          "date_range" => "all",
          "filters" => [["is", "event:props:author", ["jane"]]],
          "dimensions" => ["event:goal"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["Scroll /blog 25"], "metrics" => [2, 0, 50.0]},
               %{"dimensions" => ["Scroll /blog 50"], "metrics" => [2, 0, 50.0]},
               %{"dimensions" => ["Scroll /blog 75"], "metrics" => [1, 0, 25.0]}
             ]
    end
  end
end
