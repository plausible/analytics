defmodule PlausibleWeb.Api.StatsController.TopStatsTest do
  use PlausibleWeb.ConnCase

  @user_id 123

  describe "GET /api/stats/top-stats - default" do
    setup [:create_user, :log_in, :create_new_site]

    test "counts distinct user ids", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id),
        build(:pageview, user_id: @user_id),
        build(:pageview)
      ])

      conn = get(conn, "/api/stats/#{site.domain}/top-stats?period=day")

      res = json_response(conn, 200)
      assert %{"name" => "Unique visitors", "value" => 2, "change" => 100} in res["top_stats"]
    end

    test "counts total pageviews", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id),
        build(:pageview, user_id: @user_id),
        build(:pageview)
      ])

      conn = get(conn, "/api/stats/#{site.domain}/top-stats?period=day")

      res = json_response(conn, 200)
      assert %{"name" => "Total pageviews", "value" => 3, "change" => 100} in res["top_stats"]
    end

    test "calculates bounce rate", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id),
        build(:pageview, user_id: @user_id),
        build(:pageview)
      ])

      conn = get(conn, "/api/stats/#{site.domain}/top-stats?period=day")

      res = json_response(conn, 200)
      assert %{"name" => "Bounce rate", "value" => 50, "change" => nil} in res["top_stats"]
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
      assert %{"name" => "Visit duration", "value" => 450, "change" => 100} in res["top_stats"]
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

      filters = Jason.encode!(%{page: "/pageA"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=day&date=2021-01-01&filters=#{filters}"
        )

      res = json_response(conn, 200)
      assert %{"name" => "Time on page", "value" => 900, "change" => 100} in res["top_stats"]
    end
  end

  describe "GET /api/stats/top-stats - realtime" do
    setup [:create_user, :log_in, :create_new_site]

    test "shows current visitors (last 5 minutes)", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: relative_time(minutes: -10)),
        build(:pageview, timestamp: relative_time(minutes: -4)),
        build(:pageview, timestamp: relative_time(minutes: -1))
      ])

      conn = get(conn, "/api/stats/#{site.domain}/top-stats?period=realtime")

      res = json_response(conn, 200)
      assert %{"name" => "Current visitors", "value" => 2} in res["top_stats"]
    end

    test "shows unique visitors (last 30 minutes)", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: relative_time(minutes: -45)),
        build(:pageview, timestamp: relative_time(minutes: -25)),
        build(:pageview, timestamp: relative_time(minutes: -1))
      ])

      conn = get(conn, "/api/stats/#{site.domain}/top-stats?period=realtime")

      res = json_response(conn, 200)
      assert %{"name" => "Unique visitors (last 30 min)", "value" => 2} in res["top_stats"]
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
      assert %{"name" => "Pageviews (last 30 min)", "value" => 3} in res["top_stats"]
    end
  end

  describe "GET /api/stats/top-stats - filters" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns only visitors from a country based on alpha2 code", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, country_code: "US"),
        build(:pageview, country_code: "US"),
        build(:pageview, country_code: "EE")
      ])

      filters = Jason.encode!(%{country: "US"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=month&filters=#{filters}"
        )

      res = json_response(conn, 200)
      assert %{"name" => "Unique visitors", "value" => 2, "change" => 100} in res["top_stats"]
    end

    test "page glob filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/index"),
        build(:pageview, pathname: "/blog/post1"),
        build(:pageview, pathname: "/blog/post2")
      ])

      filters = Jason.encode!(%{page: "/blog/**"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=month&filters=#{filters}"
        )

      res = json_response(conn, 200)
      assert %{"name" => "Unique visitors", "value" => 2, "change" => 100} in res["top_stats"]
    end

    test "contains (~) filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/some-blog-post"),
        build(:pageview, pathname: "/blog/post1"),
        build(:pageview, pathname: "/another/post")
      ])

      filters = Jason.encode!(%{page: "~blog"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=month&filters=#{filters}"
        )

      res = json_response(conn, 200)
      assert %{"name" => "Unique visitors", "value" => 2, "change" => 100} in res["top_stats"]
    end

    test "returns only visitors with specific screen size", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, screen_size: "Desktop"),
        build(:pageview, screen_size: "Desktop"),
        build(:pageview, screen_size: "Mobile")
      ])

      filters = Jason.encode!(%{screen: "Desktop"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=month&filters=#{filters}"
        )

      res = json_response(conn, 200)
      assert %{"name" => "Unique visitors", "value" => 2, "change" => 100} in res["top_stats"]
    end

    test "returns only visitors with specific browser", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, browser: "Chrome"),
        build(:pageview, browser: "Chrome"),
        build(:pageview, browser: "Safari")
      ])

      filters = Jason.encode!(%{browser: "Chrome"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=month&filters=#{filters}"
        )

      res = json_response(conn, 200)
      assert %{"name" => "Unique visitors", "value" => 2, "change" => 100} in res["top_stats"]
    end

    test "returns only visitors with specific operating system", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, operating_system: "Mac"),
        build(:pageview, operating_system: "Mac"),
        build(:pageview, operating_system: "Windows")
      ])

      filters = Jason.encode!(%{os: "Mac"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=month&filters=#{filters}"
        )

      res = json_response(conn, 200)
      assert %{"name" => "Unique visitors", "value" => 2, "change" => 100} in res["top_stats"]
    end
  end

  describe "GET /api/stats/top-stats - filtered for goal" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns total unique visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id),
        build(:pageview, user_id: @user_id),
        build(:pageview),
        build(:event, name: "Signup")
      ])

      filters = Jason.encode!(%{goal: "Signup"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=day&filters=#{filters}"
        )

      res = json_response(conn, 200)
      assert %{"name" => "Unique visitors", "value" => 3, "change" => 100} in res["top_stats"]
    end

    test "returns converted visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id),
        build(:pageview, user_id: @user_id),
        build(:pageview),
        build(:event, name: "Signup")
      ])

      filters = Jason.encode!(%{goal: "Signup"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=month&filters=#{filters}"
        )

      res = json_response(conn, 200)
      assert %{"name" => "Unique conversions", "value" => 1, "change" => 100} in res["top_stats"]
    end

    test "returns conversion rate", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id),
        build(:pageview, user_id: @user_id),
        build(:pageview),
        build(:event, name: "Signup")
      ])

      filters = Jason.encode!(%{goal: "Signup"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=day&filters=#{filters}"
        )

      res = json_response(conn, 200)

      assert %{"name" => "Conversion rate", "value" => 33.3, "change" => 100} in res["top_stats"]
    end
  end
end
