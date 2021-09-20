defmodule PlausibleWeb.Api.StatsController.PagesTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils
  @user_id 123

  describe "GET /api/stats/:domain/pages" do
    setup [:create_user, :log_in, :create_new_site]

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

      assert json_response(conn, 200) == [
               %{"count" => 3, "name" => "/"},
               %{"count" => 2, "name" => "/register"},
               %{"count" => 1, "name" => "/contact"}
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

      assert json_response(conn, 200) == [
               %{
                 "bounce_rate" => 50.0,
                 "time_on_page" => 900.0,
                 "count" => 2,
                 "pageviews" => 2,
                 "name" => "/"
               },
               %{
                 "bounce_rate" => nil,
                 "time_on_page" => nil,
                 "count" => 1,
                 "pageviews" => 1,
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

      assert json_response(conn, 200) == [
               %{"count" => 2, "name" => "/page1"},
               %{"count" => 1, "name" => "/page2"}
             ]
    end

    test "calculates conversion_rate when filtering for goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, pathname: "/"),
        build(:pageview, user_id: 2, pathname: "/"),
        build(:pageview, user_id: 3, pathname: "/"),
        build(:event, user_id: 3, name: "Signup")
      ])

      filters = Jason.encode!(%{"goal" => "Signup"})

      conn = get(conn, "/api/stats/#{site.domain}/pages?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{"count" => 1, "name" => "/", "conversion_rate" => 33.3}
             ]
    end
  end

  describe "GET /api/stats/:domain/entry-pages" do
    setup [:create_user, :log_in, :create_new_site]

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

      assert json_response(conn, 200) == [
               %{
                 "count" => 2,
                 "entries" => 2,
                 "name" => "/page1",
                 "visit_duration" => 0
               },
               %{
                 "count" => 1,
                 "entries" => 2,
                 "name" => "/page2",
                 "visit_duration" => 450
               }
             ]
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

      filters = Jason.encode!(%{"goal" => "Signup"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/entry-pages?period=day&date=2021-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "count" => 1,
                 "entries" => 1,
                 "name" => "/page2",
                 "visit_duration" => 900,
                 "conversion_rate" => 100.0
               },
               %{
                 "count" => 1,
                 "entries" => 1,
                 "name" => "/page1",
                 "visit_duration" => 0,
                 "conversion_rate" => 50.0
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/exit-pages" do
    setup [:create_user, :log_in, :create_new_site]

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

      assert json_response(conn, 200) == [
               %{"name" => "/page1", "count" => 2, "exits" => 2, "exit_rate" => 66},
               %{"name" => "/page2", "count" => 1, "exits" => 1, "exit_rate" => 100}
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

      filters = Jason.encode!(%{"goal" => "Signup"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/exit-pages?period=day&date=2021-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "/exit1",
                 "count" => 1,
                 "exits" => 1,
                 "exit_rate" => 50,
                 "conversion_rate" => 100.0
               },
               %{
                 "name" => "/exit2",
                 "count" => 1,
                 "exits" => 1,
                 "exit_rate" => 100,
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

      filters = Jason.encode!(%{"page" => "/exit1"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/exit-pages?period=day&date=2021-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{"name" => "/exit1", "count" => 1, "exits" => 1, "exit_rate" => 50},
               %{"name" => "/exit2", "count" => 1, "exits" => 1, "exit_rate" => 100}
             ]
    end
  end
end
