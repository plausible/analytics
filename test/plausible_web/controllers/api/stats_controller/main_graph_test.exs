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

  describe "GET /api/stats/main-graph - unique visitors" do
    setup [:create_user, :log_in, :create_site]

    test "counts distinct user ids", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain, user_id: @user_id, timestamp: ~N[2019-01-01 00:00:00])
      insert(:pageview, hostname: site.domain, user_id: @user_id, timestamp: ~N[2019-01-01 23:59:00])

      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-01")

      assert %{"unique_visitors" => 1} = json_response(conn, 200)
    end

    test "does not count custom events", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-01 00:00:00])
      insert(:event, name: "Custom", hostname: site.domain, timestamp: ~N[2019-01-01 00:00:00])

      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-01")

      assert %{"unique_visitors" => 1} = json_response(conn, 200)
    end
  end

  describe "GET /api/stats/main-graph - pageviews" do
    setup [:create_user, :log_in, :create_site]

    test "counts total pageviews even from same user ids", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain, user_id: @user_id, timestamp: ~N[2019-01-01 00:00:00])
      insert(:pageview, hostname: site.domain, user_id: @user_id, timestamp: ~N[2019-01-01 23:59:00])

      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-01")

      assert %{"pageviews" => 2} = json_response(conn, 200)
    end

    test "does not count custom events", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-01 00:00:00])
      insert(:event, name: "Custom", hostname: site.domain, timestamp: ~N[2019-01-01 00:00:00])

      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-01")

      assert %{"unique_visitors" => 1} = json_response(conn, 200)
    end
  end

  describe "GET /api/stats/main-graph - comparisons" do
    setup [:create_user, :log_in, :create_site]

    test "compares unique users with previous time period", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain, user_id: @user_id, timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, hostname: site.domain, user_id: @user_id, timestamp: ~N[2019-01-01 02:00:00])

      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-02 01:00:00])
      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-02 02:00:00])

      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-02")

      assert %{"change_visitors" => 100} = json_response(conn, 200)
    end

    test "compares pageviews with previous time period", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-01 02:00:00])

      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-02 02:00:00])

      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-02")

      assert %{"change_pageviews" => -50} = json_response(conn, 200)
    end
  end

  describe "GET /api/stats/main-graph - conversion rate" do
    setup [:create_user, :log_in, :create_site]

    test "returns conversion rate when filtering for a goal", %{conn: conn, site: site} do
      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-01 02:00:00])
      insert(:pageview, hostname: site.domain, user_id: @user_id, timestamp: ~N[2019-01-01 01:00:00])
      insert(:event, name: "Signup", hostname: site.domain, user_id: @user_id, timestamp: ~N[2019-01-01 02:00:00])

      filters = Jason.encode!(%{goal: "Signup"})
      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=day&date=2019-01-01&filters=#{filters}")

      assert %{"conversion_rate" => 50} = json_response(conn, 200)
    end
  end

  defp months_ago(months) do
    Timex.now() |> Timex.shift(months: -months)
  end
end
