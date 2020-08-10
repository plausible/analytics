defmodule PlausibleWeb.Api.StatsController.MainGraphTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/main-graph - plot" do
    setup [:create_user, :log_in, :create_site]

    test "displays pageviews for the last 30 minutes in realtime graph", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=realtime")

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 30
      assert Enum.any?(plot, fn pageviews -> pageviews > 0 end)
    end

    test "displays visitors for a day", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-01")

      assert %{"plot" => plot} = json_response(conn, 200)

      zeroes = Stream.repeatedly(fn -> 0 end) |> Stream.take(22) |> Enum.into([])

      assert Enum.count(plot) == 24
      assert plot == [3] ++ zeroes ++ [3]
    end

    test "displays hourly stats in configured timezone", %{conn: conn, user: user} do
      # UTC+1
      site = insert(:site, domain: "tz-test.com", members: [user], timezone: "CET")

      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-01")

      assert %{"plot" => plot} = json_response(conn, 200)

      zeroes = Stream.repeatedly(fn -> 0 end) |> Stream.take(22) |> Enum.into([])

      # Expecting pageview to show at 1am CET
      assert plot == [0, 1] ++ zeroes
    end

    test "displays visitors for a month", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=month&date=2019-01-01")

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 31
      assert List.first(plot) == 6
      assert List.last(plot) == 1
    end

    # TODO: missing 6, 12 months, 30 days
  end

  describe "GET /api/stats/main-graph - labels" do
    setup [:create_user, :log_in, :create_site]

    test "shows last 30 days", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=30d")
      assert %{"labels" => labels} = json_response(conn, 200)

      {:ok, first} = Timex.today() |> Timex.shift(days: -30) |> Timex.format("{ISOdate}")
      {:ok, last} = Timex.today() |> Timex.format("{ISOdate}")
      assert List.first(labels) == first
      assert List.last(labels) == last
    end

    test "shows last 7 days", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=7d")
      assert %{"labels" => labels} = json_response(conn, 200)

      {:ok, first} = Timex.today() |> Timex.shift(days: -7) |> Timex.format("{ISOdate}")
      {:ok, last} = Timex.today() |> Timex.format("{ISOdate}")
      assert List.first(labels) == first
      assert List.last(labels) == last
    end
  end

  describe "GET /api/stats/main-graph - top stats" do
    setup [:create_user, :log_in, :create_site]

    test "counts distinct user ids", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-01")

      res = json_response(conn, 200)
      assert %{"name" => "Unique visitors", "count" => 9, "change" => 100} in res["top_stats"]
    end

    test "counts total pageviews", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-01")

      res = json_response(conn, 200)
      assert %{"name" => "Total pageviews", "count" => 9, "change" => 100} in res["top_stats"]
    end

    test "calculates bounce rate", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-01")

      res = json_response(conn, 200)
      assert %{"name" => "Bounce rate", "percentage" => 33.0, "change" => nil} in res["top_stats"]
    end

    test "calculates average visit duration", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-01")

      res = json_response(conn, 200)
      assert %{"name" => "Visit duration", "count" => 67.0, "change" => 100} in res["top_stats"]
    end
  end

  describe "GET /api/stats/main-graph - filtered for goal" do
    setup [:create_user, :log_in, :create_site]

    test "returns total unique visitors", %{conn: conn, site: site} do
      filters = Jason.encode!(%{goal: "Signup"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-01&filters=#{filters}"
        )

      res = json_response(conn, 200)
      assert %{"name" => "Total visitors", "count" => 6, "change" => 100} in res["top_stats"]
    end

    test "returns converted visitors", %{conn: conn, site: site} do
      filters = Jason.encode!(%{goal: "Signup"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2019-01-01&filters=#{filters}"
        )

      res = json_response(conn, 200)
      assert %{"name" => "Converted visitors", "count" => 3, "change" => 100} in res["top_stats"]
    end

    test "returns conversion rate", %{conn: conn, site: site} do
      filters = Jason.encode!(%{goal: "Signup"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-01&filters=#{filters}"
        )

      res = json_response(conn, 200)

      assert %{"name" => "Conversion rate", "percentage" => 50.0, "change" => 100} in res[
               "top_stats"
             ]
    end
  end
end
