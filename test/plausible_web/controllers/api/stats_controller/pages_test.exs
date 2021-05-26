defmodule PlausibleWeb.Api.StatsController.PagesTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/pages" do
    setup [:create_user, :log_in, :create_site]

    test "returns top pages by visitors", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/pages?period=day&date=2019-01-01")

      assert json_response(conn, 200) == [
               %{"count" => 3, "pageviews" => 3, "name" => "/"},
               %{"count" => 2, "pageviews" => 2, "name" => "/register"},
               %{"count" => 1, "pageviews" => 1, "name" => "/contact"},
               %{"count" => 1, "pageviews" => 1, "name" => "/irrelevant"}
             ]
    end

    test "calculates bounce rate and time on page for pages", %{conn: conn, site: site} do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2019-01-01&detailed=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "time_on_page" => 82800,
                 "bounce_rate" => 33.0,
                 "count" => 3,
                 "pageviews" => 3,
                 "name" => "/"
               },
               %{
                 "time_on_page" => 1,
                 "bounce_rate" => nil,
                 "count" => 2,
                 "pageviews" => 2,
                 "name" => "/register"
               },
               %{
                 "time_on_page" => nil,
                 "bounce_rate" => nil,
                 "count" => 1,
                 "pageviews" => 1,
                 "name" => "/contact"
               },
               %{
                 "time_on_page" => nil,
                 "bounce_rate" => nil,
                 "count" => 1,
                 "pageviews" => 1,
                 "name" => "/irrelevant"
               }
             ]
    end

    test "filters pages based on wildards", %{conn: conn, site: site} do
      filters = Jason.encode!(%{page: "/*re*"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2019-01-01&detailed=true&filters=#{
            filters
          }"
        )

      assert json_response(conn, 200) == [
               %{
                 "time_on_page" => 1,
                 "bounce_rate" => nil,
                 "count" => 2,
                 "pageviews" => 2,
                 "name" => "/register"
               },
               %{
                 "time_on_page" => nil,
                 "bounce_rate" => nil,
                 "count" => 1,
                 "pageviews" => 1,
                 "name" => "/irrelevant"
               }
             ]
    end

    test "filters pages based on exclusion", %{conn: conn, site: site} do
      filters = Jason.encode!(%{page: "!/"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2019-01-01&detailed=true&filters=#{
            filters
          }"
        )

      assert json_response(conn, 200) == [
               %{
                 "time_on_page" => 1,
                 "bounce_rate" => nil,
                 "count" => 2,
                 "pageviews" => 2,
                 "name" => "/register"
               },
               %{
                 "time_on_page" => nil,
                 "bounce_rate" => nil,
                 "count" => 1,
                 "pageviews" => 1,
                 "name" => "/contact"
               },
               %{
                 "time_on_page" => nil,
                 "bounce_rate" => nil,
                 "count" => 1,
                 "pageviews" => 1,
                 "name" => "/irrelevant"
               }
             ]
    end

    test "filters pages based on wildard exclusion", %{conn: conn, site: site} do
      filters = Jason.encode!(%{page: "!/*re*"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2019-01-01&detailed=true&filters=#{
            filters
          }"
        )

      assert json_response(conn, 200) == [
               %{
                 "time_on_page" => 82800,
                 "bounce_rate" => 33.0,
                 "count" => 3,
                 "pageviews" => 3,
                 "name" => "/"
               },
               %{
                 "time_on_page" => nil,
                 "bounce_rate" => nil,
                 "count" => 1,
                 "pageviews" => 1,
                 "name" => "/contact"
               }
             ]
    end

    test "returns top pages in realtime report", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/pages?period=realtime")

      assert json_response(conn, 200) == [
               %{"count" => 2, "name" => "/exit"},
               %{"count" => 1, "name" => "/"}
             ]
    end
  end

  describe "GET /api/stats/:domain/entry-pages" do
    setup [:create_user, :log_in, :create_site]

    test "returns top entry pages by visitors", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/entry-pages?period=day&date=2019-01-01")

      assert json_response(conn, 200) == [
               %{
                 "count" => 3,
                 "entries" => 3,
                 "name" => "/",
                 "visit_duration" => 67
               }
             ]
    end

    test "calculates visit duration for entry pages", %{conn: conn, site: site} do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/entry-pages?period=day&date=2019-01-01"
        )

      assert json_response(conn, 200) == [
               %{
                 "visit_duration" => 67,
                 "count" => 3,
                 "entries" => 3,
                 "name" => "/"
               }
             ]
    end

    test "filters based on exclusion for entry pages", %{conn: conn, site: site} do
      filters = Jason.encode!(%{entry_page: "!/"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/entry-pages?period=day&date=2019-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == []
    end
  end

  describe "GET /api/stats/:domain/exit-pages" do
    setup [:create_user, :log_in, :create_site]

    test "returns top exit pages by visitors", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/exit-pages?period=day&date=2019-01-01")

      assert json_response(conn, 200) == [
               %{"count" => 3, "exits" => 3, "name" => "/", "exit_rate" => 100.0}
             ]
    end

    test "filters based on exclusion for entry pages", %{conn: conn, site: site} do
      filters = Jason.encode!(%{exit_page: "!/"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/exit-pages?period=day&date=2019-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == []
    end
  end
end
