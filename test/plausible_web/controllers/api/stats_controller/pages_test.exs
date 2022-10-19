defmodule PlausibleWeb.Api.StatsController.PagesTest do
  use PlausibleWeb.ConnCase

  @user_id 123

  describe "GET /api/stats/:domain/pages" do
    setup [:create_user, :log_in, :create_new_site, :add_imported_data]

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
               %{"visitors" => 3, "name" => "/"},
               %{"visitors" => 2, "name" => "/register"},
               %{"visitors" => 1, "name" => "/contact"}
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

      filters = Jason.encode!(%{props: %{"author" => "John Doe"}})
      conn = get(conn, "/api/stats/#{site.domain}/pages?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
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

      filters = Jason.encode!(%{props: %{"author" => "!John Doe"}})
      conn = get(conn, "/api/stats/#{site.domain}/pages?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{"visitors" => 1, "name" => "/"},
               %{"visitors" => 1, "name" => "/blog/other-post"}
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

      filters = Jason.encode!(%{props: %{"author" => "John Doe"}})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}&detailed=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "/blog/john-2",
                 "visitors" => 2,
                 "pageviews" => 2,
                 "bounce_rate" => 0,
                 "time_on_page" => 600
               },
               %{
                 "name" => "/blog/john-1",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => 0,
                 "time_on_page" => 60
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

      filters = Jason.encode!(%{props: %{"author" => "!John Doe"}})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}&detailed=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "/blog",
                 "visitors" => 2,
                 "pageviews" => 2,
                 "bounce_rate" => 0,
                 "time_on_page" => 120.0
               },
               %{
                 "name" => "/blog/other-post",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => nil,
                 "time_on_page" => nil
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

      filters = Jason.encode!(%{props: %{"author" => "(none)"}})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}&detailed=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "/blog",
                 "visitors" => 2,
                 "pageviews" => 2,
                 "bounce_rate" => 50,
                 "time_on_page" => 60
               },
               %{
                 "name" => "/blog/other-post",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => nil,
                 "time_on_page" => nil
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

      filters = Jason.encode!(%{props: %{"author" => "!(none)"}})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}&detailed=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "/blog/other-post",
                 "visitors" => 2,
                 "pageviews" => 2,
                 "bounce_rate" => 100,
                 "time_on_page" => nil
               },
               %{
                 "name" => "/blog/john-1",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => 0,
                 "time_on_page" => 60
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

      filters = Jason.encode!(%{page: "/"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}&detailed=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "/",
                 "visitors" => 2,
                 "pageviews" => 3,
                 "bounce_rate" => 50,
                 "time_on_page" => 60
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

      conn = get(conn, "/api/stats/#{site.domain}/pages?period=day")

      assert json_response(conn, 200) == [
               %{"visitors" => 3, "name" => "/"},
               %{"visitors" => 2, "name" => "/register"},
               %{"visitors" => 1, "name" => "/contact"}
             ]

      conn = get(conn, "/api/stats/#{site.domain}/pages?period=day&with_imported=true")

      assert json_response(conn, 200) == [
               %{"visitors" => 4, "name" => "/"},
               %{"visitors" => 3, "name" => "/register"},
               %{"visitors" => 1, "name" => "/contact"}
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
                 "visitors" => 2,
                 "pageviews" => 2,
                 "name" => "/"
               },
               %{
                 "bounce_rate" => nil,
                 "time_on_page" => nil,
                 "visitors" => 1,
                 "pageviews" => 1,
                 "name" => "/some-other-page"
               }
             ]
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

      assert json_response(conn, 200) == [
               %{
                 "bounce_rate" => 40.0,
                 "time_on_page" => 800.0,
                 "visitors" => 3,
                 "pageviews" => 3,
                 "name" => "/"
               },
               %{
                 "bounce_rate" => nil,
                 "time_on_page" => 60,
                 "visitors" => 2,
                 "pageviews" => 2,
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

      filters = Jason.encode!(%{"goal" => "Signup"})

      conn = get(conn, "/api/stats/#{site.domain}/pages?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{"total_visitors" => 3, "visitors" => 1, "name" => "/", "conversion_rate" => 33.3}
             ]
    end
  end

  describe "GET /api/stats/:domain/entry-pages" do
    setup [:create_user, :log_in, :create_new_site, :add_imported_data]

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
                 "unique_entrances" => 2,
                 "total_entrances" => 2,
                 "name" => "/page1",
                 "visit_duration" => 0
               },
               %{
                 "unique_entrances" => 1,
                 "total_entrances" => 2,
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

      filters = Jason.encode!(%{props: %{"author" => "John Doe"}})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/entry-pages?period=day&date=2021-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "unique_entrances" => 1,
                 "total_entrances" => 1,
                 "name" => "/blog",
                 "visit_duration" => 60
               },
               %{
                 "unique_entrances" => 1,
                 "total_entrances" => 1,
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

      conn = get(conn, "/api/stats/#{site.domain}/entry-pages?period=day&date=2021-01-01")

      assert json_response(conn, 200) == [
               %{
                 "unique_entrances" => 2,
                 "total_entrances" => 2,
                 "name" => "/page1",
                 "visit_duration" => 0
               },
               %{
                 "unique_entrances" => 1,
                 "total_entrances" => 2,
                 "name" => "/page2",
                 "visit_duration" => 450
               }
             ]

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/entry-pages?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "unique_entrances" => 3,
                 "total_entrances" => 5,
                 "name" => "/page2",
                 "visit_duration" => 240.0
               },
               %{
                 "unique_entrances" => 2,
                 "total_entrances" => 2,
                 "name" => "/page1",
                 "visit_duration" => 0
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
                 "total_visitors" => 1,
                 "unique_entrances" => 1,
                 "total_entrances" => 1,
                 "name" => "/page2",
                 "visit_duration" => 900,
                 "conversion_rate" => 100.0
               },
               %{
                 "total_visitors" => 2,
                 "unique_entrances" => 1,
                 "total_entrances" => 1,
                 "name" => "/page1",
                 "visit_duration" => 0,
                 "conversion_rate" => 50.0
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/exit-pages" do
    setup [:create_user, :log_in, :create_new_site, :add_imported_data]

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
               %{"name" => "/page1", "unique_exits" => 2, "total_exits" => 2, "exit_rate" => 66},
               %{"name" => "/page2", "unique_exits" => 1, "total_exits" => 1, "exit_rate" => 100}
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

      filters = Jason.encode!(%{props: %{"author" => "John Doe"}})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/exit-pages?period=day&date=2021-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{"name" => "/", "unique_exits" => 1, "total_exits" => 1}
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

      conn = get(conn, "/api/stats/#{site.domain}/exit-pages?period=day&date=2021-01-01")

      assert json_response(conn, 200) == [
               %{"name" => "/page1", "unique_exits" => 2, "total_exits" => 2, "exit_rate" => 66},
               %{"name" => "/page2", "unique_exits" => 1, "total_exits" => 1, "exit_rate" => 100}
             ]

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/exit-pages?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "/page2",
                 "unique_exits" => 3,
                 "total_exits" => 4,
                 "exit_rate" => 80.0
               },
               %{"name" => "/page1", "unique_exits" => 2, "total_exits" => 2, "exit_rate" => 66}
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
                 "unique_exits" => 1,
                 "total_visitors" => 1,
                 "total_exits" => 1,
                 "conversion_rate" => 100.0
               },
               %{
                 "name" => "/exit2",
                 "unique_exits" => 1,
                 "total_visitors" => 1,
                 "total_exits" => 1,
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
               %{"name" => "/exit1", "unique_exits" => 1, "total_exits" => 1},
               %{"name" => "/exit2", "unique_exits" => 1, "total_exits" => 1}
             ]
    end
  end
end
