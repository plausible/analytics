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

      filters = Jason.encode!(%{props: %{"browser" => "!Chrome|Safari"}})

      conn =
        get(conn, "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}")

      assert json_response(conn, 200) == [
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

      filters = Jason.encode!(%{props: %{"browser" => "!Chrome|(none)"}})

      conn =
        get(conn, "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}")

      assert json_response(conn, 200) == [
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

      filters = Jason.encode!(%{page: "/about|/"})

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
               },
               %{
                 "name" => "/about",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => 100,
                 "time_on_page" => nil
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

      filters = Jason.encode!(%{page: "!/irrelevant|/about"})

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

      filters = Jason.encode!(%{page: "/blog/**|/articles/**"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}&detailed=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "/articles/post-1",
                 "visitors" => 2,
                 "pageviews" => 2,
                 "bounce_rate" => 100,
                 "time_on_page" => nil
               },
               %{
                 "name" => "/blog/post-1",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => 0,
                 "time_on_page" => 60
               },
               %{
                 "name" => "/blog/post-2",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => nil,
                 "time_on_page" => nil
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

      filters = Jason.encode!(%{page: "/blog/(/**|/blog/)/**"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}&detailed=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "/blog/(/post-1",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => 0,
                 "time_on_page" => 60
               },
               %{
                 "name" => "/blog/(/post-2",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => nil,
                 "time_on_page" => nil
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

      filters = Jason.encode!(%{page: "!/blog/**|/articles/**"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}&detailed=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "/",
                 "visitors" => 2,
                 "pageviews" => 2,
                 "bounce_rate" => 50,
                 "time_on_page" => 600
               },
               %{
                 "name" => "/about",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => nil,
                 "time_on_page" => nil
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

      filters = Jason.encode!(%{props: %{"author" => "John Doe"}})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/entry-pages?period=day&date=2021-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
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

      conn = get(conn, "/api/stats/#{site.domain}/entry-pages?period=day&date=2021-01-01")

      assert json_response(conn, 200) == [
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

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/entry-pages?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn, 200) == [
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

      request = fn conn, opts ->
        page = Keyword.fetch!(opts, :page)
        limit = Keyword.fetch!(opts, :limit)
        filters = Jason.encode!(%{"goal" => "Signup"})

        conn
        |> get(
          "/api/stats/#{site.domain}/pages?date=2021-01-01&period=day&filters=#{filters}&limit=#{limit}&page=#{page}"
        )
        |> json_response(200)
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

      filters = Jason.encode!(%{"goal" => "Signup"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/entry-pages?period=day&date=2021-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "total_visitors" => 2,
                 "visitors" => 1,
                 "visits" => 1,
                 "name" => "/page1",
                 "visit_duration" => 0,
                 "conversion_rate" => 50.0
               },
               %{
                 "total_visitors" => 1,
                 "visitors" => 1,
                 "visits" => 1,
                 "name" => "/page2",
                 "visit_duration" => 900,
                 "conversion_rate" => 100.0
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
               %{"name" => "/page1", "visitors" => 2, "visits" => 2, "exit_rate" => 66},
               %{"name" => "/page2", "visitors" => 1, "visits" => 1, "exit_rate" => 100}
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

      conn = get(conn, "/api/stats/#{site.domain}/exit-pages?period=day&date=2021-01-01")

      assert json_response(conn, 200) == [
               %{"name" => "/page1", "visitors" => 2, "visits" => 2, "exit_rate" => 66},
               %{"name" => "/page2", "visitors" => 1, "visits" => 1, "exit_rate" => 100}
             ]

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/exit-pages?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn, 200) == [
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

      filters = Jason.encode!(%{"goal" => "Signup"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/exit-pages?period=day&date=2021-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "/exit1",
                 "visitors" => 1,
                 "total_visitors" => 1,
                 "visits" => 1,
                 "conversion_rate" => 100.0
               },
               %{
                 "name" => "/exit2",
                 "visitors" => 1,
                 "total_visitors" => 1,
                 "visits" => 1,
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
               %{"name" => "/exit1", "visitors" => 1, "visits" => 1},
               %{"name" => "/exit2", "visitors" => 1, "visits" => 1}
             ]
    end
  end
end
