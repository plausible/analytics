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

      assert_matches json_response(conn, 200), %{
        "results" => [
          %{"dimensions" => ["Purchase"], "metrics" => [2]},
          %{"dimensions" => ["Visit /test"], "metrics" => [1]}
        ],
        "meta" => %{},
        "query" =>
          response_query(site, %{
            "metrics" => ["visitors"],
            "dimensions" => ["event:goal"]
          })
      }
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

      assert_matches json_response(conn, 200), %{
        "results" => [
          %{"dimensions" => ["Visit /blog**"], "metrics" => [2, 4]},
          %{"dimensions" => ["Visit /**/post"], "metrics" => [2, 2]}
        ],
        "meta" => %{},
        "query" =>
          response_query(site, %{
            "metrics" => ["visitors", "pageviews"],
            "dimensions" => ["event:goal"]
          })
      }
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

      assert_matches json_response(conn, 200), %{
        "results" => [],
        "meta" => %{},
        "query" =>
          response_query(site, %{
            "metrics" => ["visitors", "pageviews"],
            "dimensions" => ["event:goal"]
          })
      }
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

      assert_matches json_response(conn, 200), %{
        "results" => [
          %{"dimensions" => ["Visit /blog**"], "metrics" => [2, 2, 50.0]},
          %{"dimensions" => ["Signup"], "metrics" => [1, 2, 25.0]}
        ],
        "meta" => %{},
        "query" =>
          response_query(site, %{
            "metrics" => ["visitors", "events", "conversion_rate"],
            "dimensions" => ["event:goal"]
          })
      }
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

      assert_matches json_response(conn, 200), %{
        "results" => [%{"dimensions" => ["Signup"], "metrics" => [50.0]}],
        "meta" => %{},
        "query" =>
          response_query(site, %{
            "metrics" => ["conversion_rate"],
            "dimensions" => ["event:goal"]
          })
      }
    end
  end
end
