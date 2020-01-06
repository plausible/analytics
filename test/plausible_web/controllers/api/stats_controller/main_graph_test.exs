defmodule PlausibleWeb.Api.StatsController.MainGraphTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils
  @user_id UUID.uuid4()

  describe "GET /api/stats/main-graph - plot" do
    setup [:create_user, :log_in, :create_site]

    test "displays visitors for a day", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-01 00:00:00])
      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-01 23:59:00])

      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-01")

      assert %{"plot" => plot} = json_response(conn, 200)

      zeroes = Stream.repeatedly(fn -> 0 end) |> Stream.take(22) |> Enum.into([])

      assert Enum.count(plot) == 24
      assert plot == [1] ++ zeroes ++ [1]
    end

    test "displays hourly stats in configured timezone", %{conn: conn, user: user} do
      site = insert(:site, members: [user], timezone: "CET") # UTC+1
      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-01 00:00:00]) # Timestamp is in UTC

      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-01")

      assert %{"plot" => plot} = json_response(conn, 200)

      zeroes = Stream.repeatedly(fn -> 0 end) |> Stream.take(22) |> Enum.into([])

      assert plot == [0, 1] ++ zeroes # Expecting pageview to show at 1am CET
    end

    test "displays visitors for a month", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-01 12:00:00])
      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-31 12:00:00])

      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=month&date=2019-01-01")

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 31
      assert List.first(plot) == 1
      assert List.last(plot) == 1
    end

    test "displays visitors for 3 months", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain)
      insert(:pageview, hostname: site.domain, timestamp: months_ago(2))

      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=3mo")

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [1, 0, 1]
    end

    # TODO: missing 6 months, 7 days, 30 days
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

    test "unique users counts distinct user ids", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain, user_id: @user_id, timestamp: ~N[2019-01-01 00:00:00])
      insert(:pageview, hostname: site.domain, user_id: @user_id, timestamp: ~N[2019-01-01 23:59:00])

      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-01")

      res = json_response(conn, 200)
      assert %{"name" => "Unique visitors", "count" => 1, "change" => 100} in res["top_stats"]
    end

    test "does not count custom events in custom user ids", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-01 00:00:00])
      insert(:event, name: "Custom", hostname: site.domain, timestamp: ~N[2019-01-01 00:00:00])

      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-01")

      res = json_response(conn, 200)
      assert %{"name" => "Unique visitors", "count" => 1, "change" => 100} in res["top_stats"]
    end

    test "counts total pageviews even from same user ids", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain, user_id: @user_id, timestamp: ~N[2019-01-01 00:00:00])
      insert(:pageview, hostname: site.domain, user_id: @user_id, timestamp: ~N[2019-01-01 23:59:00])

      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-01")

      res = json_response(conn, 200)
      assert %{"name" => "Total pageviews", "count" => 2, "change" => 100} in res["top_stats"]
    end

    test "compares pageviews with previous time period", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-01 02:00:00])

      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-02 02:00:00])

      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-02")

      res = json_response(conn, 200)
      assert %{"name" => "Total pageviews", "count" => 1, "change" => -50} in res["top_stats"]
    end

    test "calculates bounce rate", %{conn: conn, site: site} do
      insert(:session, hostname: site.domain, is_bounce: true, start: ~N[2019-01-01 01:00:00])
      insert(:session, hostname: site.domain, is_bounce: false, start: ~N[2019-01-01 02:00:00])

      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-01")

      res = json_response(conn, 200)
      assert %{"name" => "Bounce rate", "percentage" => 50, "change" => nil} in res["top_stats"]
    end

    test "calculates change in bounce rate", %{conn: conn, site: site} do
      insert(:session, hostname: site.domain, is_bounce: true, start: ~N[2019-01-01 01:00:00])
      insert(:session, hostname: site.domain, is_bounce: false, start: ~N[2019-01-01 02:00:00])

      insert(:session, hostname: site.domain, is_bounce: true, start: ~N[2019-01-02 01:00:00])
      insert(:session, hostname: site.domain, is_bounce: true, start: ~N[2019-01-02 01:00:00])
      insert(:session, hostname: site.domain, is_bounce: false, start: ~N[2019-01-02 02:00:00])

      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-02")

      res = json_response(conn, 200)
      assert %{"name" => "Bounce rate", "percentage" => 67, "change" => 17} in res["top_stats"]
    end

    test "calculates avg session length", %{conn: conn, site: site} do
      insert(:session, hostname: site.domain, length: 10, start: ~N[2019-01-01 01:00:00])
      insert(:session, hostname: site.domain, length: 20, start: ~N[2019-01-01 02:00:00])

      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-01")

      res = json_response(conn, 200)
      assert %{"name" => "Session length", "duration" => 15, "change" => nil} in res["top_stats"]
    end

    test "calculates change in session length", %{conn: conn, site: site} do
      insert(:session, hostname: site.domain, length: 10, start: ~N[2019-01-01 01:00:00])
      insert(:session, hostname: site.domain, length: 20, start: ~N[2019-01-01 02:00:00])

      insert(:session, hostname: site.domain, length: 20, start: ~N[2019-01-02 02:00:00])

      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-02")

      res = json_response(conn, 200)
      assert %{"name" => "Session length", "duration" => 20, "change" => 5} in res["top_stats"]
    end
  end


  describe "GET /api/stats/main-graph - filtered for goal" do
    setup [:create_user, :log_in, :create_site]

    test "returns total unique visitors", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-01 02:00:00])
      insert(:pageview, hostname: site.domain, user_id: @user_id, timestamp: ~N[2019-01-01 01:00:00])
      insert(:event, name: "Signup", hostname: site.domain, user_id: @user_id, timestamp: ~N[2019-01-01 02:00:00])

      filters = Jason.encode!(%{goal: "Signup"})
      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-01&filters=#{filters}")

      res = json_response(conn, 200)
      assert %{"name" => "Total visitors", "count" => 2, "change" => 100} in res["top_stats"]
    end

    test "returns converted visitors", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-01 02:00:00])
      insert(:pageview, hostname: site.domain, user_id: @user_id, timestamp: ~N[2019-01-01 01:00:00])
      insert(:event, name: "Signup", hostname: site.domain, user_id: @user_id, timestamp: ~N[2019-01-01 02:00:00])

      filters = Jason.encode!(%{goal: "Signup"})
      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=month&date=2019-01-01&filters=#{filters}")

      res = json_response(conn, 200)
      assert %{"name" => "Converted visitors", "count" => 1, "change" => 100} in res["top_stats"]
    end

    test "returns conversion rate", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-01 02:00:00])
      insert(:pageview, hostname: site.domain, user_id: @user_id, timestamp: ~N[2019-01-01 01:00:00])
      insert(:event, name: "Signup", hostname: site.domain, user_id: @user_id, timestamp: ~N[2019-01-01 02:00:00])

      filters = Jason.encode!(%{goal: "Signup"})
      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-01&filters=#{filters}")

      res = json_response(conn, 200)
      assert %{"name" => "Conversion rate", "percentage" => 50.0, "change" => 100} in res["top_stats"]
    end
  end

  defp months_ago(months) do
    Timex.now() |> Timex.shift(months: -months)
  end
end
