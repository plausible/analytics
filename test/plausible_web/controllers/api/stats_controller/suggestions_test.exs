defmodule PlausibleWeb.Api.StatsController.SuggestionsTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/suggestions/:filter_name" do
    setup [:create_user, :log_in, :create_site]

    test "returns suggestions for pages without a query", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/suggestions/page?period=month&date=2019-01-01")

      assert json_response(conn, 200) == ["/", "/register", "/contact", "/irrelevant"]
    end

    test "returns suggestions for pages with a query", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/page?period=month&date=2019-01-01&q=re")

      assert json_response(conn, 200) == ["/register", "/irrelevant"]
    end

    test "returns suggestions for pages without any suggestions", %{conn: conn, site: site} do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/page?period=month&date=2019-01-01&q=/123"
        )

      assert json_response(conn, 200) == []
    end

    test "returns suggestions for goals", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/suggestions/goal?period=month&date=2019-01-01")

      assert json_response(conn, 200) == []
    end

    test "returns suggestions for sources", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/source?period=month&date=2019-01-01")

      assert json_response(conn, 200) == ["10words", "Bing"]
    end

    test "returns suggestions for countries", %{conn: conn, site: site} do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/country?period=month&date=2019-01-01&q=GBR,UKR,URY,USA"
        )

      assert json_response(conn, 200) == ["USA"]
    end

    test "returns suggestions for countries without country in search", %{conn: conn, site: site} do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/country?period=month&date=2019-01-01&q=GBR,UKR,URY"
        )

      assert json_response(conn, 200) == []
    end

    test "returns suggestions for screen sizes", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/screen?period=month&date=2019-01-01")

      assert json_response(conn, 200) == ["Desktop"]
    end

    test "returns suggestions for browsers", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/browser?period=month&date=2019-01-01")

      assert json_response(conn, 200) == ["Chrome"]
    end

    test "returns suggestions for browser versions", %{conn: conn, site: site} do
      filters = Jason.encode!(%{browser: "Chrome"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/browser_version?period=month&date=2019-01-01&filters=#{
            filters
          }"
        )

      assert json_response(conn, 200) == ["78.0"]
    end

    test "returns suggestions for OS", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/suggestions/os?period=month&date=2019-01-01")

      assert json_response(conn, 200) == ["Mac"]
    end

    test "returns suggestions for OS versions", %{conn: conn, site: site} do
      filters = Jason.encode!(%{os: "Mac"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/os_version?period=month&date=2019-01-01&filters=#{
            filters
          }"
        )

      assert json_response(conn, 200) == ["10.15"]
    end

    test "returns suggestions for OS versions with search", %{conn: conn, site: site} do
      filters = Jason.encode!(%{os: "Mac"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/os_version?period=month&date=2019-01-01&filters=#{
            filters
          }&q=11"
        )

      assert json_response(conn, 200) == []
    end

    test "returns suggestions for referrers", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/referrer?period=month&date=2019-01-01")

      assert json_response(conn, 200) == ["10words.com/page1"]
    end
  end
end
