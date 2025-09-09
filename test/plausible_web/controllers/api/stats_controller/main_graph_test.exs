defmodule PlausibleWeb.Api.StatsController.MainGraphTest do
  use PlausibleWeb.ConnCase
  use Plausible.Teams.Test

  @user_id Enum.random(1000..9999)

  describe "GET /api/stats/main-graph - plot" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "displays pageviews for the last 30 minutes in realtime graph", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: relative_time(minutes: -5))
      ])

      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=realtime&metric=pageviews")

      assert %{"plot" => plot, "labels" => labels} = json_response(conn, 200)

      assert labels == Enum.to_list(-30..-1)
      assert Enum.count(plot) == 30
      assert Enum.any?(plot, fn pageviews -> pageviews > 0 end)
    end

    test "displays pageviews for the last 30 minutes for a non-UTC timezone site", %{
      conn: conn,
      site: site
    } do
      Plausible.Site.changeset(site, %{timezone: "Europe/Tallinn"})
      |> Plausible.Repo.update()

      populate_stats(site, [
        build(:pageview, timestamp: relative_time(minutes: -5))
      ])

      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=realtime&metric=pageviews")

      assert %{"plot" => plot, "labels" => labels} = json_response(conn, 200)

      assert labels == Enum.to_list(-30..-1)
      assert Enum.count(plot) == 30
      assert Enum.any?(plot, fn pageviews -> pageviews > 0 end)
    end

    test "displays pageviews for a day", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 23:00:00])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=day&date=2021-01-01&metric=pageviews"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      zeroes = List.duplicate(0, 22)

      assert Enum.count(plot) == 24
      assert plot == [1] ++ zeroes ++ [1]
    end

    test "returns empty plot with no native data and recently imported from ga in realtime graph",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors, date: Date.utc_today()),
        build(:imported_visitors, date: Date.utc_today())
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=realtime&with_imported=true"
        )

      zeroes = List.duplicate(0, 30)
      assert %{"plot" => ^zeroes} = json_response(conn, 200)
    end

    test "imported data is not included for hourly interval", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00]),
        build(:imported_visitors, date: ~D[2021-01-01]),
        build(:imported_visitors, date: ~D[2021-01-31])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=day&date=2021-01-01&with_imported=true"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [1] ++ List.duplicate(0, 23)
    end

    test "displays hourly stats in configured timezone", %{conn: conn, user: user} do
      # UTC+1
      site =
        new_site(
          domain: "tz-test.com",
          owner: user,
          timezone: "CET"
        )

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=day&date=2021-01-01&metric=visitors"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      zeroes = List.duplicate(0, 22)

      # Expecting pageview to show at 1am CET
      assert plot == [0, 1] ++ zeroes
    end

    test "displays visitors for a month", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&metric=visitors"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 31
      assert List.first(plot) == 1
      assert List.last(plot) == 1
      assert Enum.sum(plot) == 2
    end

    test "displays visitors for last 28d", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-28 00:00:00])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=28d&date=2021-01-29&metric=visitors"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 28
      assert List.first(plot) == 1
      assert List.last(plot) == 1
      assert Enum.sum(plot) == 2
    end

    test "displays visitors for last 91d", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-16 00:00:00]),
        build(:pageview, timestamp: ~N[2021-04-16 00:00:00])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=91d&date=2021-04-17&metric=visitors"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 91
      assert List.first(plot) == 1
      assert List.last(plot) == 1
      assert Enum.sum(plot) == 2
    end

    test "displays visitors for a month with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00]),
        build(:imported_visitors, date: ~D[2021-01-01]),
        build(:imported_visitors, date: ~D[2021-01-31])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&with_imported=true"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 31
      assert List.first(plot) == 2
      assert List.last(plot) == 2
      assert Enum.sum(plot) == 4
    end

    test "displays visitors for a month with only imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors, date: ~D[2021-01-01]),
        build(:imported_visitors, date: ~D[2021-01-31])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&with_imported=true"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 31
      assert List.first(plot) == 1
      assert List.last(plot) == 1
      assert Enum.sum(plot) == 2
    end

    test "displays visitors for a month with imported data and filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00], pathname: "/pageA"),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00], pathname: "/pageA"),
        build(:imported_visitors, date: ~D[2021-01-01]),
        build(:imported_visitors, date: ~D[2021-01-31])
      ])

      filters = Jason.encode!([[:is, "event:page", ["/pageA"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&with_imported=true&filters=#{filters}"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 31
      assert List.first(plot) == 1
      assert List.last(plot) == 1
      assert Enum.sum(plot) == 2
    end

    test "displays visitors for 6 months with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-12-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-05-31 00:00:00]),
        build(:imported_visitors, date: ~D[2020-12-01]),
        build(:imported_visitors, date: ~D[2021-05-31])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=6mo&date=2021-06-30&with_imported=true"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 6
      assert List.first(plot) == 2
      assert List.last(plot) == 2
      assert Enum.sum(plot) == 4
    end

    test "displays visitors for 6 months with only imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors, date: ~D[2020-12-01]),
        build(:imported_visitors, date: ~D[2021-05-31])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=6mo&date=2021-06-30&with_imported=true"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 6
      assert List.first(plot) == 1
      assert List.last(plot) == 1
      assert Enum.sum(plot) == 2
    end

    test "displays visitors for 12 months with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-12-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-11-30 00:00:00]),
        build(:imported_visitors, date: ~D[2020-12-01]),
        build(:imported_visitors, date: ~D[2021-11-30])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=12mo&date=2021-12-31&with_imported=true"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 12
      assert List.first(plot) == 2
      assert List.last(plot) == 2
      assert Enum.sum(plot) == 4
    end

    test "displays visitors for 12 months with only imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors, date: ~D[2020-12-01]),
        build(:imported_visitors, date: ~D[2021-11-30])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=12mo&date=2021-12-31&with_imported=true"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 12
      assert List.first(plot) == 1
      assert List.last(plot) == 1
      assert Enum.sum(plot) == 2
    end

    test "displays visitors for calendar year with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-12-31 00:00:00]),
        build(:imported_visitors, date: ~D[2021-01-01]),
        build(:imported_visitors, date: ~D[2021-12-31])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=year&date=2021-12-31&with_imported=true"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 12
      assert List.first(plot) == 2
      assert List.last(plot) == 2
      assert Enum.sum(plot) == 4
    end

    test "displays visitors for calendar year with only imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors, date: ~D[2021-01-01]),
        build(:imported_visitors, date: ~D[2021-12-31])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=year&date=2021-12-31&with_imported=true"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 12
      assert List.first(plot) == 1
      assert List.last(plot) == 1
      assert Enum.sum(plot) == 2
    end

    test "displays visitors for all time with just native data", %{conn: conn, site: site} do
      use Plausible.Repo

      Repo.update_all(from(s in "sites", where: s.id == ^site.id),
        set: [stats_start_date: ~D[2020-01-01]]
      )

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-12-31 00:00:00])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=all&with_imported=true"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert List.first(plot) == 1
      assert Enum.sum(plot) == 3
    end
  end

  describe "GET /api/stats/main-graph - default labels" do
    setup [:create_user, :log_in, :create_site]

    test "shows last 30 days", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=30d&metric=visitors")
      assert %{"labels" => labels} = json_response(conn, 200)

      {:ok, first} = Date.utc_today() |> Timex.shift(days: -30) |> Timex.format("{ISOdate}")
      {:ok, last} = Date.utc_today() |> Timex.shift(days: -1) |> Timex.format("{ISOdate}")
      assert List.first(labels) == first
      assert List.last(labels) == last
    end

    test "shows last 7 days", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/main-graph?period=7d&metric=visitors")
      assert %{"labels" => labels} = json_response(conn, 200)

      {:ok, first} = Date.utc_today() |> Timex.shift(days: -7) |> Timex.format("{ISOdate}")
      {:ok, last} = Date.utc_today() |> Timex.shift(days: -1) |> Timex.format("{ISOdate}")
      assert List.first(labels) == first
      assert List.last(labels) == last
    end
  end

  describe "GET /api/stats/main-graph - pageviews plot" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "displays pageviews for a month", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&metric=pageviews"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 31
      assert List.first(plot) == 2
      assert List.last(plot) == 1
    end

    test "displays pageviews for a month with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00]),
        build(:imported_visitors, date: ~D[2021-01-01]),
        build(:imported_visitors, date: ~D[2021-01-31])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&metric=pageviews&with_imported=true"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 31
      assert List.first(plot) == 2
      assert List.last(plot) == 2
      assert Enum.sum(plot) == 4
    end

    test "displays pageviews for a month with only imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors, date: ~D[2021-01-01]),
        build(:imported_visitors, date: ~D[2021-01-31])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&metric=pageviews&with_imported=true"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 31
      assert List.first(plot) == 1
      assert List.last(plot) == 1
      assert Enum.sum(plot) == 2
    end
  end

  describe "GET /api/stats/main-graph - visitors plot" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "displays visitors per hour with short visits", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00], user_id: 1),
        build(:pageview, timestamp: ~N[2021-01-01 00:10:00], user_id: 1),
        build(:pageview, timestamp: ~N[2021-01-01 00:20:00])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=day&date=2021-01-01&metric=visitors&interval=hour"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 24
      assert List.first(plot) == 2
      assert Enum.sum(plot) == 2
    end

    test "displays visitors realtime with visits spanning multiple minutes", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, timestamp: relative_time(minutes: -35), user_id: 1),
        build(:pageview, timestamp: relative_time(minutes: -20), user_id: 1),
        build(:pageview, timestamp: relative_time(minutes: -25), user_id: 2),
        build(:pageview, timestamp: relative_time(minutes: -15), user_id: 2),
        build(:pageview, timestamp: relative_time(minutes: -5), user_id: 3),
        build(:pageview, timestamp: relative_time(minutes: -3), user_id: 3)
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=realtime&metric=visitors"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      expected_plot = ~w[1 1 1 1 1 2 2 2 2 2 2 1 1 1 1 1 0 0 0 0 0 0 0 0 0 1 1 1 0 0]
      assert plot == Enum.map(expected_plot, &String.to_integer/1)
    end

    test "displays visitors per hour with visits spanning multiple hours", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-12-31 23:45:00], user_id: 1),
        build(:pageview, timestamp: ~N[2021-01-01 00:10:00], user_id: 1),
        build(:pageview, timestamp: ~N[2021-01-01 00:15:00], user_id: 1),
        build(:pageview, timestamp: ~N[2021-01-01 00:35:00], user_id: 2),
        build(:pageview, timestamp: ~N[2021-01-01 01:00:00], user_id: 2),
        build(:pageview, timestamp: ~N[2021-01-01 01:25:00], user_id: 2),
        build(:pageview, timestamp: ~N[2021-01-01 01:50:00], user_id: 2),
        build(:pageview, timestamp: ~N[2021-01-01 02:05:00], user_id: 2),
        build(:pageview, timestamp: ~N[2021-01-01 23:45:00], user_id: 3),
        build(:pageview, timestamp: ~N[2021-01-02 00:05:00], user_id: 3)
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=day&date=2021-01-01&metric=visitors&interval=hour"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      zeroes = List.duplicate(0, 20)
      assert [2, 1, 1] ++ zeroes ++ [1] == plot
    end

    test "displays visitors per day with visits showed only in last time bucket", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-12-31 23:45:00], user_id: 1),
        build(:pageview, timestamp: ~N[2021-01-01 00:10:00], user_id: 1),
        build(:pageview, timestamp: ~N[2020-01-02 23:45:00], user_id: 2),
        build(:pageview, timestamp: ~N[2021-01-03 00:10:00], user_id: 2),
        build(:pageview, timestamp: ~N[2020-01-03 23:45:00], user_id: 3),
        build(:pageview, timestamp: ~N[2021-01-04 00:10:00], user_id: 3),
        build(:pageview, timestamp: ~N[2020-01-07 23:45:00], user_id: 4),
        build(:pageview, timestamp: ~N[2021-01-08 00:10:00], user_id: 4)
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=7d&date=2021-01-08&metric=visitors&interval=day"
        )

      assert %{"plot" => plot} = json_response(conn, 200)
      assert plot == [1, 0, 1, 1, 0, 0, 0]
    end

    test "displays visitors per week with visits showed only in last time bucket", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-12-31 23:45:00], user_id: 1),
        build(:pageview, timestamp: ~N[2021-01-01 00:10:00], user_id: 1),
        build(:pageview, timestamp: ~N[2020-01-03 23:45:00], user_id: 2),
        build(:pageview, timestamp: ~N[2021-01-04 00:10:00], user_id: 2),
        build(:pageview, timestamp: ~N[2021-01-31 23:45:00], user_id: 3),
        build(:pageview, timestamp: ~N[2021-02-01 00:05:00], user_id: 3)
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&metric=visitors&interval=week"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [1, 1, 0, 0, 0]
    end
  end

  describe "GET /api/stats/main-graph - scroll_depth plot" do
    setup [:create_user, :log_in, :create_site]

    test "returns 400 when scroll_depth is queried without a page filter", %{
      conn: conn,
      site: site
    } do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&metric=scroll_depth"
        )

      assert %{"error" => error} = json_response(conn, 400)
      assert error =~ "can only be queried with a page filter"
    end

    test "returns scroll depth per day", %{conn: conn, site: site} do
      t0 = ~N[2020-01-01 00:00:00]
      [t1, t2, t3] = for i <- 1..3, do: NaiveDateTime.add(t0, i, :minute)

      populate_stats(site, [
        build(:pageview, user_id: 12, timestamp: t0),
        build(:engagement, user_id: 12, timestamp: t1, scroll_depth: 20),
        build(:pageview, user_id: 34, timestamp: t0),
        build(:engagement, user_id: 34, timestamp: t1, scroll_depth: 17),
        build(:pageview, user_id: 34, timestamp: t2),
        build(:engagement, user_id: 34, timestamp: t3, scroll_depth: 60),
        build(:pageview, user_id: 56, timestamp: NaiveDateTime.add(t0, 1, :day)),
        build(:engagement,
          user_id: 56,
          timestamp: NaiveDateTime.add(t1, 1, :day),
          scroll_depth: 20
        )
      ])

      filters = Jason.encode!([[:is, "event:page", ["/"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=7d&date=2020-01-08&metric=scroll_depth&filters=#{filters}"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [40, 20, nil, nil, nil, nil, nil]
    end

    test "returns scroll depth per day with imported data", %{conn: conn, site: site} do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        # 2020-01-01 - only native data
        build(:pageview, user_id: 12, timestamp: ~N[2020-01-01 00:00:00]),
        build(:engagement, user_id: 12, timestamp: ~N[2020-01-01 00:01:00], scroll_depth: 20),
        build(:pageview, user_id: 34, timestamp: ~N[2020-01-01 00:00:00]),
        build(:engagement, user_id: 34, timestamp: ~N[2020-01-01 00:01:00], scroll_depth: 17),
        build(:pageview, user_id: 34, timestamp: ~N[2020-01-01 00:02:00]),
        build(:engagement, user_id: 34, timestamp: ~N[2020-01-01 00:03:00], scroll_depth: 60),
        # 2020-01-02 - both imported and native data
        build(:pageview, user_id: 56, timestamp: ~N[2020-01-02 00:00:00]),
        build(:engagement, user_id: 56, timestamp: ~N[2020-01-02 00:01:00], scroll_depth: 20),
        build(:imported_pages,
          date: ~D[2020-01-02],
          page: "/",
          visitors: 1,
          total_scroll_depth: 40,
          total_scroll_depth_visits: 1
        ),
        # 2020-01-03 - only imported data
        build(:imported_pages,
          date: ~D[2020-01-03],
          page: "/",
          visitors: 1,
          total_scroll_depth: 90,
          total_scroll_depth_visits: 1
        ),
        build(:imported_pages, date: ~D[2020-01-03], page: "/", visitors: 100)
      ])

      filters = Jason.encode!([[:is, "event:page", ["/"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=7d&date=2020-01-08&metric=scroll_depth&filters=#{filters}&with_imported=true"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [40, 30, 90, nil, nil, nil, nil]
    end
  end

  describe "GET /api/stats/main-graph - conversion_rate plot" do
    setup [:create_user, :log_in, :create_site]

    test "returns 400 when conversion rate is queried without a goal filter", %{
      conn: conn,
      site: site
    } do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&metric=conversion_rate"
        )

      assert %{"error" => error} = json_response(conn, 400)
      assert error =~ "can only be queried with a goal filter"
    end

    test "displays conversion_rate for a month", %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Signup")

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2021-01-31 00:00:00])
      ])

      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&metric=conversion_rate&filters=#{filters}"
        )

      assert %{"plot" => plot} = json_response(conn, 200)
      assert Enum.count(plot) == 31

      assert List.first(plot) == 33.33
      assert Enum.at(plot, 10) == 0.0
      assert List.last(plot) == 50.0
    end
  end

  describe "GET /api/stats/main-graph - events (total conversions) plot" do
    setup [:create_user, :log_in, :create_site]

    test "returns 400 when the `events` metric is queried without a goal filter", %{
      conn: conn,
      site: site
    } do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&metric=events"
        )

      assert %{"error" => error} = json_response(conn, 400)
      assert error =~ "`events` can only be queried with a goal filter"
    end

    test "displays total conversions for a goal", %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Signup")

      populate_stats(site, [
        build(:event, name: "Different", timestamp: ~N[2021-01-01 00:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2021-01-01 00:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00]),
        build(:event, name: "Signup", user_id: 123, timestamp: ~N[2021-01-31 00:00:00]),
        build(:event, name: "Signup", user_id: 123, timestamp: ~N[2021-01-31 00:00:00]),
        build(:event, name: "Signup", user_id: 123, timestamp: ~N[2021-01-31 00:00:00])
      ])

      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&metric=events&filters=#{filters}"
        )

      assert %{"plot" => plot} = json_response(conn, 200)
      assert Enum.count(plot) == 31

      assert List.first(plot) == 2
      assert Enum.at(plot, 10) == 0.0
      assert List.last(plot) == 3
    end

    test "displays total conversions per hour with previous day comparison plot", %{
      conn: conn,
      site: site
    } do
      insert(:goal, site: site, event_name: "Signup")

      populate_stats(site, [
        build(:event, name: "Different", timestamp: ~N[2021-01-10 05:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2021-01-10 05:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2021-01-10 05:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2021-01-10 19:00:00]),
        build(:pageview, timestamp: ~N[2021-01-10 19:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2021-01-11 04:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2021-01-11 05:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2021-01-11 18:00:00])
      ])

      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=day&date=2021-01-11&metric=events&filters=#{filters}&comparison=previous_period"
        )

      assert %{"plot" => curr, "comparison_plot" => prev} = json_response(conn, 200)
      assert [0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0] = prev
      assert [0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0] = curr
    end

    test "displays conversions per month with 12mo comparison plot", %{
      conn: conn,
      site: site
    } do
      insert(:goal, site: site, event_name: "Signup")

      populate_stats(site, [
        build(:event, name: "Different", timestamp: ~N[2019-12-10 00:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2020-01-10 00:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2020-02-10 00:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2020-03-10 00:00:00]),
        build(:pageview, timestamp: ~N[2021-04-10 00:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2021-05-11 04:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2021-06-11 00:00:00]),
        build(:event, name: "Signup", timestamp: ~N[2021-07-11 00:00:00])
      ])

      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=12mo&date=2021-12-11&metric=events&filters=#{filters}&comparison=previous_period"
        )

      assert %{"plot" => curr, "comparison_plot" => prev} = json_response(conn, 200)
      assert [0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0] = prev
      assert [0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0] = curr
    end
  end

  describe "GET /api/stats/main-graph - bounce_rate plot" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "displays bounce_rate for a month", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-03 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-03 00:10:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&metric=bounce_rate"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 31
      assert List.first(plot) == 0
      assert List.last(plot) == 100
    end

    test "displays bounce rate for a month with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00]),
        build(:imported_visitors, visits: 1, bounces: 0, date: ~D[2021-01-01]),
        build(:imported_visitors, visits: 1, bounces: 1, date: ~D[2021-01-31])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&metric=bounce_rate&with_imported=true"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 31
      assert List.first(plot) == 50
      assert List.last(plot) == 100
    end

    test "displays bounce rate for a month with only imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors, visits: 1, bounces: 0, date: ~D[2021-01-01]),
        build(:imported_visitors, visits: 1, bounces: 1, date: ~D[2021-01-31])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&metric=bounce_rate&with_imported=true"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 31
      assert List.first(plot) == 0
      assert List.last(plot) == 100
    end
  end

  describe "GET /api/stats/main-graph - visit_duration plot" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "displays visit_duration for a month", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/page3",
          user_id: @user_id,
          timestamp: ~N[2021-01-31 00:10:00]
        ),
        build(:pageview,
          pathname: "/page2",
          user_id: @user_id,
          timestamp: ~N[2021-01-31 00:15:00]
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&metric=visit_duration"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 31
      assert List.first(plot) == nil
      assert List.last(plot) == 300
    end

    test "displays visit_duration for a month with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:10:00]),
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:15:00]),
        build(:imported_visitors, visits: 1, visit_duration: 100, date: ~D[2021-01-01])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&metric=visit_duration&with_imported=true"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 31
      assert List.first(plot) == 200
    end

    test "displays visit_duration for a month with only imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors, visits: 1, visit_duration: 100, date: ~D[2021-01-01])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&metric=visit_duration&with_imported=true"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 31
      assert List.first(plot) == 100
    end
  end

  describe "GET /api/stats/main-graph - varying intervals" do
    setup [:create_user, :log_in, :create_site]

    test "displays visitors for 6mo on a day scale", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-12-01 00:00:00]),
        build(:pageview, timestamp: ~N[2020-12-15 00:00:00]),
        build(:pageview, timestamp: ~N[2020-12-15 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-15 00:00:00]),
        build(:pageview, timestamp: ~N[2021-05-31 01:00:00])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=6mo&date=2021-06-01&metric=visitors&interval=day"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 182
      assert List.first(plot) == 1
      assert Enum.at(plot, 14) == 2
      assert Enum.at(plot, 45) == 1
      assert List.last(plot) == 1
    end

    test "displays visitors for a custom period on a monthly scale", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-15 00:00:00]),
        build(:pageview, timestamp: ~N[2021-02-15 00:00:00]),
        build(:pageview, timestamp: ~N[2021-06-01 00:00:00])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=custom&from=2021-01-01&to=2021-06-30&metric=visitors&interval=month"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 6
      assert List.first(plot) == 2
      assert Enum.at(plot, 1) == 1
      assert List.last(plot) == 1
    end

    test "returns error when requesting an interval longer than the time period", %{
      conn: conn,
      site: site
    } do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=day&date=2021-01-01&metric=visitors&interval=month"
        )

      assert %{
               "error" =>
                 "Invalid combination of interval and period. Interval must be smaller than the selected period, e.g. `period=day,interval=minute`"
             } == json_response(conn, 400)
    end

    test "returns error when the interval is not valid", %{
      conn: conn,
      site: site
    } do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=day&date=2021-01-01&metric=visitors&interval=biweekly"
        )

      assert %{
               "error" =>
                 "Invalid value for interval. Accepted values are: minute, hour, day, week, month"
             } == json_response(conn, 400)
    end

    test "displays visitors for a month on a weekly scale", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:15:01]),
        build(:pageview, timestamp: ~N[2021-01-05 00:15:02])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&metric=visitors&interval=week"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert Enum.count(plot) == 5
      assert List.first(plot) == 2
      assert Enum.at(plot, 1) == 1
    end

    test "shows imperfect week-split month on week scale with full week indicators", %{
      conn: conn,
      site: site
    } do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&metric=visitors&interval=week&date=2021-09-01"
        )

      assert %{"labels" => labels, "full_intervals" => full_intervals} = json_response(conn, 200)

      assert labels == ["2021-09-01", "2021-09-06", "2021-09-13", "2021-09-20", "2021-09-27"]

      assert full_intervals == %{
               "2021-09-01" => false,
               "2021-09-06" => true,
               "2021-09-13" => true,
               "2021-09-20" => true,
               "2021-09-27" => false
             }
    end

    test "returns stats for the first week of the month when site timezone is ahead of UTC", %{
      conn: conn,
      site: site
    } do
      site =
        site
        |> Plausible.Site.changeset(%{timezone: "Europe/Copenhagen"})
        |> Plausible.Repo.update!()

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2023-03-01 12:00:00])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&metric=visitors&date=2023-03-01&interval=week"
        )

      %{"labels" => labels, "plot" => plot} = json_response(conn, 200)

      assert List.first(plot) == 1
      assert List.first(labels) == "2023-03-01"
    end

    test "shows half-perfect week-split month on week scale with full week indicators", %{
      conn: conn,
      site: site
    } do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&metric=visitors&interval=week&date=2021-10-01"
        )

      assert %{"labels" => labels, "full_intervals" => full_intervals} = json_response(conn, 200)

      assert labels == ["2021-10-01", "2021-10-04", "2021-10-11", "2021-10-18", "2021-10-25"]

      assert full_intervals == %{
               "2021-10-01" => false,
               "2021-10-04" => true,
               "2021-10-11" => true,
               "2021-10-18" => true,
               "2021-10-25" => true
             }
    end

    test "shows perfect week-split range on week scale with full week indicators for custom period",
         %{
           conn: conn,
           site: site
         } do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=custom&metric=visitors&interval=week&from=2020-12-21&to=2021-02-07"
        )

      assert %{"labels" => labels, "full_intervals" => full_intervals} = json_response(conn, 200)

      assert labels == [
               "2020-12-21",
               "2020-12-28",
               "2021-01-04",
               "2021-01-11",
               "2021-01-18",
               "2021-01-25",
               "2021-02-01"
             ]

      assert full_intervals == %{
               "2020-12-21" => true,
               "2020-12-28" => true,
               "2021-01-04" => true,
               "2021-01-11" => true,
               "2021-01-18" => true,
               "2021-01-25" => true,
               "2021-02-01" => true
             }
    end

    test "shows imperfect week-split for last 28d with full week indicators", %{
      conn: conn,
      site: site
    } do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=28d&metric=visitors&interval=week&date=2021-10-30"
        )

      assert %{"labels" => labels, "full_intervals" => full_intervals} = json_response(conn, 200)

      assert labels == ["2021-10-02", "2021-10-04", "2021-10-11", "2021-10-18", "2021-10-25"]

      assert full_intervals == %{
               "2021-10-02" => false,
               "2021-10-04" => true,
               "2021-10-11" => true,
               "2021-10-18" => true,
               "2021-10-25" => false
             }
    end

    test "shows perfect week-split for last 28d with full week indicators", %{
      conn: conn,
      site: site
    } do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=28d&date=2021-02-08&metric=visitors&interval=week"
        )

      assert %{"labels" => labels, "full_intervals" => full_intervals} = json_response(conn, 200)

      assert labels == ["2021-01-11", "2021-01-18", "2021-01-25", "2021-02-01"]

      assert full_intervals == %{
               "2021-01-11" => true,
               "2021-01-18" => true,
               "2021-01-25" => true,
               "2021-02-01" => true
             }
    end

    test "shows imperfect month-split for custom period with full month indicators", %{
      conn: conn,
      site: site
    } do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=custom&metric=visitors&interval=month&from=2021-09-06&to=2021-12-13"
        )

      assert %{"labels" => labels, "full_intervals" => full_intervals} = json_response(conn, 200)

      assert labels == ["2021-09-01", "2021-10-01", "2021-11-01", "2021-12-01"]

      assert full_intervals == %{
               "2021-09-01" => false,
               "2021-10-01" => true,
               "2021-11-01" => true,
               "2021-12-01" => false
             }
    end

    test "shows imperfect month-split for last 91d with full month indicators", %{
      conn: conn,
      site: site
    } do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=91d&metric=visitors&interval=month&date=2021-12-13"
        )

      assert %{"labels" => labels, "full_intervals" => full_intervals} = json_response(conn, 200)

      assert labels == ["2021-09-01", "2021-10-01", "2021-11-01", "2021-12-01"]

      assert full_intervals == %{
               "2021-09-01" => false,
               "2021-10-01" => true,
               "2021-11-01" => true,
               "2021-12-01" => false
             }
    end

    test "shows perfect month-split for last 91d with full month indicators", %{
      conn: conn,
      site: site
    } do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=91d&metric=visitors&interval=month&date=2021-12-01"
        )

      assert %{"labels" => labels, "full_intervals" => full_intervals} = json_response(conn, 200)

      assert labels == ["2021-09-01", "2021-10-01", "2021-11-01"]

      assert full_intervals == %{
               "2021-09-01" => true,
               "2021-10-01" => true,
               "2021-11-01" => true
             }
    end

    test "returns stats for a day with a minute interval", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2023-03-01 12:00:00])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=day&metric=visitors&date=2023-03-01&interval=minute"
        )

      %{"labels" => labels, "plot" => plot} = json_response(conn, 200)

      assert length(labels) == 24 * 60

      assert List.first(labels) == "2023-03-01 00:00:00"
      assert Enum.at(labels, 1) == "2023-03-01 00:01:00"
      assert List.last(labels) == "2023-03-01 23:59:00"

      assert Enum.at(plot, Enum.find_index(labels, &(&1 == "2023-03-01 12:00:00"))) == 1
    end

    test "trims hourly relative date range", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-08 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-08 06:05:00]),
        build(:pageview, timestamp: ~N[2021-01-08 08:59:00]),
        build(:pageview, timestamp: ~N[2021-01-08 23:59:00])
      ])

      Plausible.Stats.Query.Test.fix_now(~U[2021-01-08 08:05:00Z])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=day&metric=visitors&date=2021-01-08&interval=hour"
        )

      assert_matches %{
                       "labels" => [
                         "2021-01-08 00:00:00",
                         "2021-01-08 01:00:00",
                         "2021-01-08 02:00:00",
                         "2021-01-08 03:00:00",
                         "2021-01-08 04:00:00",
                         "2021-01-08 05:00:00",
                         "2021-01-08 06:00:00",
                         "2021-01-08 07:00:00",
                         "2021-01-08 08:00:00"
                       ],
                       "plot" => [1, 0, 0, 0, 0, 0, 1, 0, 1]
                     } = json_response(conn, 200)
    end

    test "trims monthly relative date range", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-05 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-07 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00])
      ])

      Plausible.Stats.Query.Test.fix_now(~U[2021-01-07 12:00:00Z])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&metric=visitors&date=2021-01-07&interval=day"
        )

      assert_matches %{
                       "labels" => [
                         "2021-01-01",
                         "2021-01-02",
                         "2021-01-03",
                         "2021-01-04",
                         "2021-01-05",
                         "2021-01-06",
                         "2021-01-07"
                       ],
                       "plot" => [1, 0, 0, 0, 1, 0, 1]
                     } = json_response(conn, 200)
    end

    test "trims yearly relative date range", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-05 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-30 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00]),
        build(:pageview, timestamp: ~N[2021-02-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-02-09 00:00:00])
      ])

      Plausible.Stats.Query.Test.fix_now(~U[2021-02-07 12:00:00Z])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=year&metric=visitors&date=2021-02-07&interval=month"
        )

      assert_matches %{
                       "labels" => [
                         "2021-01-01",
                         "2021-02-01"
                       ],
                       "plot" => [4, 1]
                     } = json_response(conn, 200)
    end
  end

  describe "GET /api/stats/main-graph - comparisons" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "returns past month stats when period=30d and comparison=previous_period", %{
      conn: conn,
      site: site
    } do
      conn =
        get(conn, "/api/stats/#{site.domain}/main-graph?period=30d&comparison=previous_period")

      assert %{"labels" => labels, "comparison_labels" => comparison_labels} =
               json_response(conn, 200)

      {:ok, first} = Date.utc_today() |> Timex.shift(days: -30) |> Timex.format("{ISOdate}")
      {:ok, last} = Date.utc_today() |> Timex.shift(days: -1) |> Timex.format("{ISOdate}")

      assert List.first(labels) == first
      assert List.last(labels) == last

      {:ok, first} = Date.utc_today() |> Timex.shift(days: -60) |> Timex.format("{ISOdate}")
      {:ok, last} = Date.utc_today() |> Timex.shift(days: -31) |> Timex.format("{ISOdate}")

      assert List.first(comparison_labels) == first
      assert List.last(comparison_labels) == last
    end

    test "returns past year stats when period=month and comparison=year_over_year", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2020-01-05 00:00:00]),
        build(:pageview, timestamp: ~N[2020-01-30 00:00:00]),
        build(:pageview, timestamp: ~N[2020-01-31 00:00:00]),
        build(:pageview, timestamp: ~N[2019-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2019-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2019-01-05 00:00:00]),
        build(:pageview, timestamp: ~N[2019-01-05 00:00:00]),
        build(:pageview, timestamp: ~N[2019-01-31 00:00:00])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2020-01-01&comparison=year_over_year"
        )

      assert %{"plot" => plot, "comparison_plot" => comparison_plot} = json_response(conn, 200)

      assert 1 == Enum.at(plot, 0)
      assert 2 == Enum.at(comparison_plot, 0)

      assert 1 == Enum.at(plot, 4)
      assert 2 == Enum.at(comparison_plot, 4)

      assert 1 == Enum.at(plot, 30)
      assert 1 == Enum.at(comparison_plot, 30)
    end

    test "fill in gaps when custom comparison period is larger than original query", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2020-01-05 00:00:00]),
        build(:pageview, timestamp: ~N[2020-01-30 00:00:00])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2020-01-01&comparison=custom&compare_from=2022-01-01&compare_to=2022-06-01"
        )

      assert %{"labels" => labels, "comparison_plot" => comparison_labels} =
               json_response(conn, 200)

      assert length(labels) == length(comparison_labels)
      assert "__blank__" == List.last(labels)
    end

    test "compares imported data and native data together", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors, date: ~D[2020-01-02]),
        build(:imported_visitors, date: ~D[2020-01-02]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=year&date=2021-01-01&with_imported=true&comparison=year_over_year&interval=month"
        )

      assert %{"plot" => plot, "comparison_plot" => comparison_plot} = json_response(conn, 200)

      assert 4 == Enum.sum(plot)
      assert 2 == Enum.sum(comparison_plot)
    end

    test "bugfix: don't crash when timezone gap occurs", %{conn: conn, user: user} do
      site = new_site(owner: user, timezone: "America/Santiago")

      populate_stats(site, [
        build(:pageview, timestamp: relative_time(minutes: -5))
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=custom&from=2022-09-11&to=2022-09-21&date=2023-03-15&with_imported=true"
        )

      assert %{"plot" => _} = json_response(conn, 200)
    end

    test "does not return imported data when with_imported is set to false when comparing", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:imported_visitors, date: ~D[2020-01-02]),
        build(:imported_visitors, date: ~D[2020-01-02]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=year&date=2021-01-01&with_imported=false&comparison=year_over_year&interval=month"
        )

      assert %{"plot" => plot, "comparison_plot" => comparison_plot} = json_response(conn, 200)

      assert 4 == Enum.sum(plot)
      assert 0 == Enum.sum(comparison_plot)
    end

    test "plots conversion rate previous period comparison", %{site: site, conn: conn} do
      insert(:goal, site: site, event_name: "Signup")

      populate_stats(site, [
        build(:event, name: "Signup", timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:01:00]),
        build(:event, name: "Signup", timestamp: ~N[2021-01-08 00:01:00]),
        build(:pageview, timestamp: ~N[2021-01-08 00:01:00])
      ])

      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=7d&date=2021-01-15&comparison=previous_period&metric=conversion_rate&filters=#{filters}"
        )

      assert %{"plot" => this_week_plot, "comparison_plot" => last_week_plot} =
               json_response(conn, 200)

      assert this_week_plot == [50.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
      assert last_week_plot == [33.33, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    end

    test "does not trim hourly relative date range when comparing", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-08 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-08 06:05:00]),
        build(:pageview, timestamp: ~N[2021-01-08 08:59:00]),
        build(:pageview, timestamp: ~N[2021-01-08 23:59:00])
      ])

      Plausible.Stats.Query.Test.fix_now(~U[2021-01-08 08:05:00Z])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=day&metric=visitors&date=2021-01-08&interval=hour&comparison=previous_period"
        )

      assert_matches %{
                       "labels" => [
                         "2021-01-08 00:00:00",
                         "2021-01-08 01:00:00",
                         "2021-01-08 02:00:00",
                         "2021-01-08 03:00:00",
                         "2021-01-08 04:00:00",
                         "2021-01-08 05:00:00",
                         "2021-01-08 06:00:00",
                         "2021-01-08 07:00:00",
                         "2021-01-08 08:00:00",
                         "2021-01-08 09:00:00",
                         "2021-01-08 10:00:00",
                         "2021-01-08 11:00:00",
                         "2021-01-08 12:00:00",
                         "2021-01-08 13:00:00",
                         "2021-01-08 14:00:00",
                         "2021-01-08 15:00:00",
                         "2021-01-08 16:00:00",
                         "2021-01-08 17:00:00",
                         "2021-01-08 18:00:00",
                         "2021-01-08 19:00:00",
                         "2021-01-08 20:00:00",
                         "2021-01-08 21:00:00",
                         "2021-01-08 22:00:00",
                         "2021-01-08 23:00:00"
                       ],
                       "plot" => [
                         1,
                         0,
                         0,
                         0,
                         0,
                         0,
                         1,
                         0,
                         1,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         1
                       ],
                       "comparison_plot" => [
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0,
                         0
                       ]
                     } = json_response(conn, 200)
    end
  end

  describe "GET /api/stats/main-graph - total_revenue plot" do
    @describetag :ee_only
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "plots total_revenue for a month", %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Payment", currency: "USD")

      populate_stats(site, [
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("13.29"),
          revenue_reporting_currency: "USD",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("19.90"),
          revenue_reporting_currency: "USD",
          timestamp: ~N[2021-01-05 00:00:00]
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("10.31"),
          revenue_reporting_currency: "USD",
          timestamp: ~N[2021-01-31 00:00:00]
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("20.0"),
          revenue_reporting_currency: "USD",
          timestamp: ~N[2021-01-31 00:00:00]
        )
      ])

      filters = Jason.encode!([[:is, "event:goal", ["Payment"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&metric=total_revenue&filters=#{filters}"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [
               %{"currency" => "USD", "long" => "$13.29", "short" => "$13.3", "value" => 13.29},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$19.90", "short" => "$19.9", "value" => 19.9},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$30.31", "short" => "$30.3", "value" => 30.31}
             ]
    end

    test "plots total_revenue for a week compared to last week", %{conn: conn, site: site} do
      insert(:goal,
        site: site,
        event_name: "Payment",
        currency: "USD",
        display_name: "PaymentUSD"
      )

      populate_stats(site, [
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("13.29"),
          revenue_reporting_currency: "USD",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("19.90"),
          revenue_reporting_currency: "USD",
          timestamp: ~N[2021-01-05 00:00:00]
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("10.31"),
          revenue_reporting_currency: "USD",
          timestamp: ~N[2021-01-10 00:00:00]
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("20.0"),
          revenue_reporting_currency: "USD",
          timestamp: ~N[2021-01-12 00:00:00]
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("10.0"),
          revenue_reporting_currency: "USD",
          timestamp: ~N[2021-01-12 01:00:00]
        )
      ])

      filters = Jason.encode!([[:is, "event:goal", ["PaymentUSD"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=7d&date=2021-01-15&metric=total_revenue&filters=#{filters}&comparison=previous_period"
        )

      assert %{"plot" => plot, "comparison_plot" => prev} = json_response(conn, 200)

      assert plot == [
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$10.31", "short" => "$10.3", "value" => 10.31},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$30.00", "short" => "$30.0", "value" => 30.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0}
             ]

      assert prev == [
               %{"currency" => "USD", "long" => "$13.29", "short" => "$13.3", "value" => 13.29},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$19.90", "short" => "$19.9", "value" => 19.9},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0}
             ]
    end
  end

  describe "GET /api/stats/main-graph - average_revenue plot" do
    @describetag :ee_only
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "plots total_revenue for a month", %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Payment", currency: "USD")

      populate_stats(site, [
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("13.29"),
          revenue_reporting_currency: "USD",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("50.50"),
          revenue_reporting_currency: "USD",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("19.90"),
          revenue_reporting_currency: "USD",
          timestamp: ~N[2021-01-05 00:00:00]
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("10.31"),
          revenue_reporting_currency: "USD",
          timestamp: ~N[2021-01-31 00:00:00]
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("20.0"),
          revenue_reporting_currency: "USD",
          timestamp: ~N[2021-01-31 00:00:00]
        )
      ])

      filters = Jason.encode!([[:is, "event:goal", ["Payment"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&metric=average_revenue&filters=#{filters}"
        )

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [
               %{"currency" => "USD", "long" => "$31.90", "short" => "$31.9", "value" => 31.895},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$19.90", "short" => "$19.9", "value" => 19.9},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$15.16", "short" => "$15.2", "value" => 15.155}
             ]
    end

    test "plots average_revenue for a week compared to last week", %{conn: conn, site: site} do
      insert(:goal,
        site: site,
        event_name: "Payment",
        currency: "USD",
        display_name: "PaymentUSD"
      )

      populate_stats(site, [
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("13.29"),
          revenue_reporting_currency: "USD",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("19.90"),
          revenue_reporting_currency: "USD",
          timestamp: ~N[2021-01-05 00:00:00]
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("10.31"),
          revenue_reporting_currency: "USD",
          timestamp: ~N[2021-01-10 00:00:00]
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("20.0"),
          revenue_reporting_currency: "USD",
          timestamp: ~N[2021-01-12 00:00:00]
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("10.0"),
          revenue_reporting_currency: "USD",
          timestamp: ~N[2021-01-12 01:00:00]
        )
      ])

      filters = Jason.encode!([[:is, "event:goal", ["PaymentUSD"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=7d&date=2021-01-15&metric=average_revenue&filters=#{filters}&comparison=previous_period"
        )

      assert %{"plot" => plot, "comparison_plot" => prev} = json_response(conn, 200)

      assert plot == [
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$10.31", "short" => "$10.3", "value" => 10.31},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$15.00", "short" => "$15.0", "value" => 15.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0}
             ]

      assert prev == [
               %{"currency" => "USD", "long" => "$13.29", "short" => "$13.3", "value" => 13.29},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$19.90", "short" => "$19.9", "value" => 19.9},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0}
             ]
    end
  end

  describe "present_index" do
    setup [:create_user, :log_in, :create_site]

    test "exists for a date range that includes the current day", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview)
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&metric=pageviews"
        )

      assert %{"present_index" => present_index} = json_response(conn, 200)

      assert present_index >= 0
    end

    test "is null for a date range that does not include the current day", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview)
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&metric=pageviews"
        )

      assert %{"present_index" => present_index} = json_response(conn, 200)

      refute present_index
    end

    for period <- ["7d", "28d", "30d", "91d"] do
      test "#{period} period does not include today", %{conn: conn, site: site} do
        today = "2021-01-01"
        yesterday = "2020-12-31"

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/main-graph?period=#{unquote(period)}&date=#{today}&metric=pageviews"
          )

        assert %{"labels" => labels, "present_index" => present_index} = json_response(conn, 200)

        refute present_index
        assert List.last(labels) == yesterday
      end
    end
  end
end
