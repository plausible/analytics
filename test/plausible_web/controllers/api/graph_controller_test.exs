defmodule PlausibleWeb.Api.GraphControllerTest do
  use PlausibleWeb.ConnCase

  defp make_request(conn, site, params) do
    post(conn, "/api/stats/#{site.domain}/main-graph-v2", params)
  end

  defp zeroes(count), do: List.duplicate(0, count)

  defp assert_time_labels(time_labels, start, step_duration, count) do
    date_mod = start.__struct__

    expected =
      start
      |> Stream.iterate(fn datetime -> date_mod.shift(datetime, step_duration) end)
      |> Enum.take(count)
      |> Enum.map(&date_mod.to_string/1)

    assert time_labels == expected
  end

  describe "date ranges and intervals" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns pageviews for 30m with a time:minute dimension", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, timestamp: relative_time(minutes: -5))
      ])

      params = %{
        "dimensions" => ["time:minute"],
        "metrics" => ["pageviews"],
        "date_range" => "30m"
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot, "labels" => labels} = json_response(conn, 200)

      assert plot == zeroes(25) ++ [1] ++ zeroes(4)
      assert labels == Enum.to_list(-30..-1)
    end

    test "returns pageviews for a day with a time:hour dimension", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 23:00:00])
      ])

      params = %{
        "dimensions" => ["time:hour"],
        "metrics" => ["pageviews"],
        "date" => "2021-01-01",
        "date_range" => "day"
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot, "labels" => labels} = json_response(conn, 200)

      assert plot == [1] ++ zeroes(22) ++ [1]
      assert_time_labels(labels, ~N[2021-01-01 00:00:00], Duration.new!(hour: 1), 24)
    end

    test "returns pageviews for 7d with a time:day dimension", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-07 00:00:00])
      ])

      params = %{
        "dimensions" => ["time:day"],
        "metrics" => ["pageviews"],
        "date" => "2021-01-07",
        "date_range" => "7d"
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot, "labels" => labels} = json_response(conn, 200)

      assert plot == [1] ++ zeroes(5) ++ [1]
      assert_time_labels(labels, ~D[2021-01-01], Duration.new!(day: 1), 7)
    end

    test "returns visitors for 30d with a time:day dimension", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-16 00:00:00]),
        build(:pageview, timestamp: ~N[2021-02-15 00:00:00])
      ])

      params = %{
        "dimensions" => ["time:day"],
        "metrics" => ["visitors"],
        "date" => "2021-02-15",
        "date_range" => "30d"
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot, "labels" => labels} = json_response(conn, 200)

      assert plot == [1] ++ zeroes(29) ++ [1]
      assert_time_labels(labels, ~D[2021-01-16], Duration.new!(day: 1), 31)
    end

    test "returns visitors for a month with a time:day dimension", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00])
      ])

      params = %{
        "dimensions" => ["time:day"],
        "metrics" => ["visitors"],
        "date" => "2021-01-01",
        "date_range" => "month"
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot, "labels" => labels} = json_response(conn, 200)

      assert plot == [1] ++ zeroes(29) ++ [1]
      assert_time_labels(labels, ~D[2021-01-01], Duration.new!(day: 1), 31)
    end

    test "returns visitors for 6mo with a time:day dimension", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-15 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-15 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-16 00:00:00]),
        build(:pageview, timestamp: ~N[2021-06-30 01:00:00])
      ])

      params = %{
        "dimensions" => ["time:day"],
        "metrics" => ["visitors"],
        "date" => "2021-06-01",
        "date_range" => "6mo"
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot, "labels" => labels} = json_response(conn, 200)

      assert plot == [1] ++ zeroes(13) ++ [2, 1] ++ zeroes(164) ++ [1]
      assert_time_labels(labels, ~D[2021-01-01], Duration.new!(day: 1), 181)
    end

    test "returns visitors for all time date_range with a time:month dimension", %{
      conn: conn,
      site: site
    } do
      site
      |> Plausible.Site.set_stats_start_date(~D[2020-01-01])
      |> Plausible.Repo.update()

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-12-31 00:00:00])
      ])

      params = %{
        "dimensions" => ["time:month"],
        "metrics" => ["visitors"],
        "date" => "2023-01-01",
        "date_range" => "all"
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot, "labels" => labels} = json_response(conn, 200)

      assert plot == [1] ++ zeroes(11) ++ [1] ++ zeroes(10) ++ [1] ++ zeroes(13)
      assert_time_labels(labels, ~D[2020-01-01], Duration.new!(month: 1), 37)
    end

    test "displays visitors for a custom date_range with a time:month dimension", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-15 00:00:00]),
        build(:pageview, timestamp: ~N[2021-02-15 00:00:00]),
        build(:pageview, timestamp: ~N[2021-06-01 00:00:00])
      ])

      params = %{
        "dimensions" => ["time:month"],
        "metrics" => ["visitors"],
        "date_range" => ["2021-01-01", "2021-06-30"],
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot, "labels" => labels} = json_response(conn, 200)

      assert plot == [2, 1, 0, 0, 0, 1]
      assert_time_labels(labels, ~D[2021-01-01], Duration.new!(month: 1), 6)
    end

    test "displays visitors for a month with a time:week dimension", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2024-07-01 00:00:00]),
        build(:pageview, timestamp: ~N[2024-07-01 00:15:01]),
        build(:pageview, timestamp: ~N[2024-07-10 00:15:02])
      ])

      params = %{
        "dimensions" => ["time:week"],
        "metrics" => ["visitors"],
        "date" => "2024-07-01",
        "date_range" => "month"
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot, "labels" => labels} = json_response(conn, 200)

      assert plot == [2, 1, 0, 0, 0]
      assert_time_labels(labels, ~D[2024-07-01], Duration.new!(week: 1), 5)
    end

    test "shows imperfect week-split for a month with full week indicators", %{
      conn: conn,
      site: site
    } do
      params = %{
        "dimensions" => ["time:week"],
        "metrics" => ["visitors"],
        "date" => "2021-09-01",
        "date_range" => "month"
      }

      conn = make_request(conn, site, params)

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

    test "shows half-perfect week-split for a month with full week indicators", %{
      conn: conn,
      site: site
    } do
      params = %{
        "dimensions" => ["time:week"],
        "metrics" => ["visitors"],
        "date" => "2021-10-01",
        "date_range" => "month"
      }

      conn = make_request(conn, site, params)

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

    test "shows perfect week-split for a custom date_range with full week indicators", %{
      conn: conn,
      site: site
    } do
      params = %{
        "dimensions" => ["time:week"],
        "metrics" => ["visitors"],
        "date_range" => ["2020-12-21", "2021-02-07"]
      }

      conn = make_request(conn, site, params)

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

    test "shows imperfect month-split period on month scale with full month indicators", %{
      conn: conn,
      site: site
    } do
      params = %{
        "dimensions" => ["time:month"],
        "metrics" => ["visitors"],
        "date_range" => ["2021-09-06", "2021-12-13"]
      }

      conn = make_request(conn, site, params)

      assert %{"labels" => labels, "full_intervals" => full_intervals} = json_response(conn, 200)

      assert labels == ["2021-09-01", "2021-10-01", "2021-11-01", "2021-12-01"]

      assert full_intervals == %{
               "2021-09-01" => false,
               "2021-10-01" => true,
               "2021-11-01" => true,
               "2021-12-01" => false
             }
    end
  end

  describe "present_index" do
    setup [:create_user, :log_in, :create_new_site]

    test "exists for a date range that includes the current day", %{conn: conn, site: site} do
      params = %{
        "dimensions" => ["time:day"],
        "date_range" => "month",
        "metrics" => ["pageviews"]
      }

      conn = make_request(conn, site, params)

      assert %{"present_index" => present_index} = json_response(conn, 200)

      assert present_index >= 0
    end

    test "is nil for a date range that does not include the current day", %{
      conn: conn,
      site: site
    } do
      params = %{
        "dimensions" => ["time:day"],
        "date_range" => "month",
        "date" => "2021-01-01",
        "metrics" => ["pageviews"]
      }

      conn = make_request(conn, site, params)

      assert %{"present_index" => present_index} = json_response(conn, 200)

      refute present_index
    end
  end

  describe "timezone" do
    setup [:create_user, :log_in, :create_new_site]

    test "displays hourly stats in configured timezone", %{conn: conn, user: user} do
      # UTC+1
      site = insert(:site, members: [user], timezone: "CET")

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      params = %{
        "dimensions" => ["time:hour"],
        "metrics" => ["pageviews"],
        "date" => "2021-01-01",
        "date_range" => "day"
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot, "labels" => labels} = json_response(conn, 200)

      assert plot == [0, 1] ++ zeroes(22)
      assert_time_labels(labels, ~N[2021-01-01 00:00:00], Duration.new!(hour: 1), 24)
    end

    test "returns stats for the first week of the month when site timezone is ahead of UTC", %{
      conn: conn,
      site: site
    } do
      site
      |> Plausible.Site.changeset(%{timezone: "Europe/Copenhagen"})
      |> Plausible.Repo.update!()

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2023-03-01 12:00:00])
      ])

      params = %{
        "dimensions" => ["time:week"],
        "metrics" => ["visitors"],
        "date" => "2023-03-01",
        "date_range" => "month"
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot, "labels" => labels} = json_response(conn, 200)

      assert List.first(plot) == 1
      assert List.first(labels) == "2023-03-01"
    end

    test "bugfix: don't crash when timezone gap occurs", %{conn: conn, user: user} do
      site = insert(:site, members: [user], timezone: "America/Santiago")

      params = %{
        "dimensions" => ["time:day"],
        "metrics" => ["visitors"],
        "date" => "2023-03-15",
        "date_range" => ["2022-09-11", "2022-09-21"],
        "include" => %{"imports" => true}
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => _} = json_response(conn, 200)
    end
  end

  describe "visits spanning multiple buckets" do
    setup [:create_user, :log_in, :create_new_site, :create_legacy_site_import]

    test "displays visitors per hour with short visits", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00], user_id: 1),
        build(:pageview, timestamp: ~N[2021-01-01 00:10:00], user_id: 1),
        build(:pageview, timestamp: ~N[2021-01-01 00:20:00])
      ])

      params = %{
        "dimensions" => ["time:hour"],
        "metrics" => ["visitors"],
        "date" => "2021-01-01",
        "date_range" => "day"
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [2] ++ zeroes(23)
    end

    test "displays visitors for a 30m period with visits spanning multiple minutes", %{
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

      params = %{
        "dimensions" => ["time:minute"],
        "metrics" => ["visitors"],
        "date_range" => "30m"
      }

      conn = make_request(conn, site, params)

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

      params = %{
        "dimensions" => ["time:hour"],
        "metrics" => ["visitors"],
        "date" => "2021-01-01",
        "date_range" => "day"
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot} = json_response(conn, 200)

      assert [2, 1, 1] ++ zeroes(20) ++ [1] == plot
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

      params = %{
        "dimensions" => ["time:day"],
        "metrics" => ["visitors"],
        "date" => "2021-01-07",
        "date_range" => "7d"
      }

      conn = make_request(conn, site, params)

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

      params = %{
        "dimensions" => ["time:week"],
        "metrics" => ["visitors"],
        "date" => "2021-01-01",
        "date_range" => "month"
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [1, 1, 0, 0, 0]
    end
  end

  describe "metrics" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns 400 when conversion_rate is queried without a goal filter", %{
      conn: conn,
      site: site
    } do
      params = %{
        "dimensions" => ["time:day"],
        "metrics" => ["conversion_rate"],
        "date" => "2021-01-01",
        "date_range" => "month"
      }

      conn = make_request(conn, site, params)

      assert json_response(conn, 400) ==
               "Metric `conversion_rate` can only be queried with event:goal filters or dimensions."
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

      params = %{
        "dimensions" => ["time:day"],
        "metrics" => ["conversion_rate"],
        "date" => "2021-01-01",
        "date_range" => "month",
        "filters" => [["is", "event:goal", ["Signup"]]]
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [33.3] ++ zeroes(29) ++ [50.0]
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

      params = %{
        "dimensions" => ["time:day"],
        "metrics" => ["events"],
        "date" => "2021-01-01",
        "date_range" => "month",
        "filters" => [["is", "event:goal", ["Signup"]]]
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [2] ++ zeroes(29) ++ [3]
    end

    @tag :ee_only
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

      params = %{
        "dimensions" => ["time:day"],
        "metrics" => ["total_revenue"],
        "date" => "2021-01-01",
        "date_range" => "month",
        "filters" => [["is", "event:goal", ["Payment"]]]
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [13.29] ++ zeroes(3) ++ [19.9] ++ zeroes(25) ++ [30.31]
    end

    test "plots average_revenue for a month", %{conn: conn, site: site} do
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

      params = %{
        "dimensions" => ["time:day"],
        "metrics" => ["average_revenue"],
        "date" => "2021-01-01",
        "date_range" => "month",
        "filters" => [["is", "event:goal", ["Payment"]]]
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [31.895] ++ zeroes(3) ++ [19.9] ++ zeroes(25) ++ [15.155]
    end

    test "displays bounce_rate for all time date range", %{conn: conn, site: site} do
      site
      |> Plausible.Site.set_stats_start_date(~D[2021-01-01])
      |> Plausible.Repo.update()

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-03 00:00:00], user_id: 1),
        build(:pageview, timestamp: ~N[2021-01-03 00:10:00], user_id: 1),
        build(:pageview, timestamp: ~N[2021-01-03 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-03 00:00:00]),
        build(:pageview, timestamp: ~N[2022-01-03 00:00:00], user_id: 2),
        build(:pageview, timestamp: ~N[2022-01-03 00:15:00], user_id: 2),
        build(:pageview, timestamp: ~N[2023-01-03 00:00:00])
      ])

      params = %{
        "dimensions" => ["time:month"],
        "metrics" => ["bounce_rate"],
        "date" => "2024-01-01",
        "date_range" => "all"
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [67] ++ zeroes(23) ++ [100] ++ zeroes(12)
    end
  end

  describe "imported data" do
    setup [:create_user, :log_in, :create_new_site, :create_legacy_site_import]

    test "returns empty plot with no native data and recently imported data with a 30m date_range",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors, date: Date.utc_today()),
        build(:imported_visitors, date: Date.utc_today())
      ])

      params = %{
        "dimensions" => ["time:minute"],
        "metrics" => ["visitors"],
        "date_range" => "30m",
        "include" => %{"imports" => true}
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == zeroes(30)
    end

    test "displays visitors for a day with native and imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:imported_visitors, date: ~D[2021-01-01]),
      ])

      params = %{
        "dimensions" => ["time:hour"],
        "metrics" => ["visitors"],
        "date" => "2021-01-01",
        "date_range" => "day",
        "include" => %{"imports" => true}
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [1] ++ zeroes(23)
    end

    test "displays visitors for a month with native and imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00]),
        build(:imported_visitors, date: ~D[2021-01-01]),
        build(:imported_visitors, date: ~D[2021-01-31])
      ])

      params = %{
        "dimensions" => ["time:day"],
        "metrics" => ["visitors"],
        "date" => "2021-01-01",
        "date_range" => "month",
        "include" => %{"imports" => true}
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [2] ++ zeroes(29) ++ [2]
    end

    test "displays visitors for a month with only imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors, date: ~D[2021-01-01]),
        build(:imported_visitors, date: ~D[2021-01-31])
      ])

      params = %{
        "dimensions" => ["time:day"],
        "metrics" => ["visitors"],
        "date" => "2021-01-01",
        "date_range" => "month",
        "include" => %{"imports" => true}
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [1] ++ zeroes(29) ++ [1]
    end

    test "displays visitors for a month with native and imported data filtered by page", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00], pathname: "/pageB"),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00], pathname: "/pageA"),
        build(:imported_pages, page: "/pageA", date: ~D[2021-01-01], visitors: 3),
        build(:imported_pages, page: "/pageB", date: ~D[2021-01-31], visitors: 5)
      ])

      params = %{
        "dimensions" => ["time:day"],
        "metrics" => ["visitors"],
        "date" => "2021-01-01",
        "date_range" => "month",
        "filters" => [["is", "event:page", ["/pageA"]]],
        "include" => %{"imports" => true}
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [3] ++ zeroes(29) ++ [1]
    end

    test "displays visitors for 6 months with native and imported data filtered by country and city_name",
         %{conn: conn, site: site} do
      london_gb_city_geoname_id = 2_643_743
      london_ca_city_geoname_id = 6_058_560

      populate_stats(site, [
        build(:pageview,
          country_code: "CA",
          city_geoname_id: london_ca_city_geoname_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          country_code: "GB",
          city_geoname_id: london_gb_city_geoname_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          country_code: "GB",
          city_geoname_id: london_gb_city_geoname_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:imported_locations,
          country: "CA",
          city: london_ca_city_geoname_id,
          date: ~D[2021-06-30]
        ),
        build(:imported_locations,
          country: "GB",
          city: london_gb_city_geoname_id,
          date: ~D[2021-06-30],
          visitors: 5
        )
      ])

      params = %{
        "dimensions" => ["time:month"],
        "metrics" => ["visitors"],
        "date" => "2021-06-30",
        "date_range" => "6mo",
        "filters" => [["is", "visit:country", ["GB"]], ["contains", "visit:city_name", ["Lon"]]],
        "include" => %{"imports" => true}
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [2, 0, 0, 0, 0, 5]
    end

    test "displays visitors for 12 months from native + imported data with a goal filter", %{
      conn: conn,
      site: site
    } do
      insert(:goal, event_name: "Outbound Link: Click", site: site)

      populate_stats(site, [
        build(:event, name: "Outbound Link: Click", timestamp: ~N[2021-01-01 00:00:00]),
        build(:event, name: "Outbound Link: Click", timestamp: ~N[2021-12-31 00:00:00]),
        build(:imported_custom_events,
          name: "Outbound Link: Click",
          date: ~D[2021-01-01],
          visitors: 2
        ),
        build(:imported_custom_events,
          name: "Outbound Link: Click",
          date: ~D[2021-12-31],
          visitors: 3
        )
      ])

      params = %{
        "dimensions" => ["time:month"],
        "metrics" => ["visitors"],
        "date" => "2021-12-31",
        "date_range" => "12mo",
        "filters" => [["is", "event:goal", ["Outbound Link: Click"]]],
        "include" => %{"imports" => true}
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [3] ++ zeroes(10) ++ [4]
    end

    test "displays pageviews for calendar year from only imported data with an entry_page filter",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_entry_pages, entry_page: "/blog/one", date: ~D[2021-01-01], pageviews: 4),
        build(:imported_entry_pages, entry_page: "/different", date: ~D[2021-06-23]),
        build(:imported_entry_pages, entry_page: "/blog/two", date: ~D[2021-12-31], pageviews: 2)
      ])

      params = %{
        "dimensions" => ["time:month"],
        "metrics" => ["pageviews"],
        "date" => "2021-04-14",
        "date_range" => "year",
        "filters" => [["contains", "visit:entry_page", ["blog"]]],
        "include" => %{"imports" => true}
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [4] ++ zeroes(10) ++ [2]
    end

    test "displays bounce_rate for 7d with only imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors, visits: 1, bounces: 0, date: ~D[2021-01-01]),
        build(:imported_visitors, visits: 2, bounces: 1, date: ~D[2021-01-02]),
        build(:imported_visitors, visits: 3, bounces: 1, date: ~D[2021-01-03]),
        build(:imported_visitors, visits: 4, bounces: 4, date: ~D[2021-01-07])
      ])

      params = %{
        "dimensions" => ["time:day"],
        "metrics" => ["bounce_rate"],
        "date" => "2021-01-07",
        "date_range" => "7d",
        "include" => %{"imports" => true}
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [0, 50, 33, 0, 0, 0, 100]
    end

    test "displays bounce_rate for 7d with native and imported data", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:imported_visitors, visits: 1, bounces: 0, date: ~D[2021-01-01]),
        build(:pageview, timestamp: ~N[2021-01-02 12:00:00]),
        build(:imported_visitors, visits: 2, bounces: 1, date: ~D[2021-01-02]),
        build(:pageview, timestamp: ~N[2021-01-03 12:00:00], user_id: 1),
        build(:pageview, timestamp: ~N[2021-01-03 12:10:00], user_id: 1),
        build(:imported_visitors, visits: 3, bounces: 1, date: ~D[2021-01-03]),
        build(:imported_visitors, visits: 4, bounces: 4, date: ~D[2021-01-07])
      ])

      params = %{
        "dimensions" => ["time:day"],
        "metrics" => ["bounce_rate"],
        "date" => "2021-01-07",
        "date_range" => "7d",
        "include" => %{"imports" => true}
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [0, 67, 25, 0, 0, 0, 100]
    end

    test "displays visit_duration for 7d with only imported data", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:imported_visitors, visits: 1, visit_duration: 0, date: ~D[2021-01-01]),
        build(:imported_visitors, visits: 2, visit_duration: 100, date: ~D[2021-01-02]),
        build(:imported_visitors, visits: 3, visit_duration: 300, date: ~D[2021-01-03]),
        build(:imported_visitors, visits: 4, visit_duration: 100, date: ~D[2021-01-07])
      ])

      params = %{
        "dimensions" => ["time:day"],
        "metrics" => ["visit_duration"],
        "date" => "2021-01-07",
        "date_range" => "7d",
        "include" => %{"imports" => true}
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [0, 50, 100, 0, 0, 0, 25]
    end

    test "displays visit_duration for 7d with native and imported data", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:imported_visitors, visits: 1, visit_duration: 10, date: ~D[2021-01-01]),
        build(:pageview, timestamp: ~N[2021-01-02 12:00:00]),
        build(:imported_visitors, visits: 2, visit_duration: 120, date: ~D[2021-01-02]),
        build(:pageview, timestamp: ~N[2021-01-03 12:00:00], user_id: 1),
        build(:pageview, timestamp: ~N[2021-01-03 12:01:40], user_id: 1),
        build(:imported_visitors, visits: 3, visit_duration: 300, date: ~D[2021-01-03]),
        build(:imported_visitors, visits: 4, visit_duration: 100, date: ~D[2021-01-07])
      ])

      params = %{
        "dimensions" => ["time:day"],
        "metrics" => ["visit_duration"],
        "date" => "2021-01-07",
        "date_range" => "7d",
        "include" => %{"imports" => true}
      }

      conn = make_request(conn, site, params)

      assert %{"plot" => plot} = json_response(conn, 200)

      assert plot == [10, 40, 100, 0, 0, 0, 25]
    end
  end

  describe "comparisons" do
    setup [:create_user, :log_in, :create_new_site, :create_legacy_site_import]

    test "returns past month stats when date_range=30d and comparison=previous_period", %{
      conn: conn,
      site: site
    } do
      conn =
        get(conn, "/api/stats/#{site.domain}/main-graph?period=30d&comparison=previous_period")

      assert %{"labels" => labels, "comparison_labels" => comparison_labels} =
                json_response(conn, 200)

      {:ok, first} = Timex.today() |> Timex.shift(days: -30) |> Timex.format("{ISOdate}")
      {:ok, last} = Timex.today() |> Timex.format("{ISOdate}")

      assert List.first(labels) == first
      assert List.last(labels) == last

      {:ok, first} = Timex.today() |> Timex.shift(days: -61) |> Timex.format("{ISOdate}")
      {:ok, last} = Timex.today() |> Timex.shift(days: -31) |> Timex.format("{ISOdate}")

      assert List.first(comparison_labels) == first
      assert List.last(comparison_labels) == last
    end
  end

  # :TODO: Adjust the below tests and include them in this file.

  # describe "GET /api/stats/main-graph - varying intervals" do
  #   setup [:create_user, :log_in, :create_new_site]

  # test "returns error when requesting an interval longer than the time period", %{
  #   conn: conn,
  #   site: site
  # } do
  #   conn =
  #     get(
  #       conn,
  #       "/api/stats/#{site.domain}/main-graph?period=day&date=2021-01-01&metric=visitors&interval=month"
  #     )

  #   assert %{
  #            "error" =>
  #              "Invalid combination of interval and period. Interval must be smaller than the selected period, e.g. `period=day,interval=minute`"
  #          } == json_response(conn, 400)
  # end

  #   test "returns error when the interval is not valid", %{
  #     conn: conn,
  #     site: site
  #   } do
  #     conn =
  #       get(
  #         conn,
  #         "/api/stats/#{site.domain}/main-graph?period=day&date=2021-01-01&metric=visitors&interval=biweekly"
  #       )

  #     assert %{
  #              "error" =>
  #                "Invalid value for interval. Accepted values are: minute, hour, day, week, month"
  #            } == json_response(conn, 400)
  #   end
  # end

  # describe "GET /api/stats/main-graph - comparisons" do
  #   setup [:create_user, :log_in, :create_new_site, :create_legacy_site_import]

  #   test "returns past year stats when period=month and comparison=year_over_year", %{
  #     conn: conn,
  #     site: site
  #   } do
  #     populate_stats(site, [
  #       build(:pageview, timestamp: ~N[2020-01-01 00:00:00]),
  #       build(:pageview, timestamp: ~N[2020-01-05 00:00:00]),
  #       build(:pageview, timestamp: ~N[2020-01-30 00:00:00]),
  #       build(:pageview, timestamp: ~N[2020-01-31 00:00:00]),
  #       build(:pageview, timestamp: ~N[2019-01-01 00:00:00]),
  #       build(:pageview, timestamp: ~N[2019-01-01 00:00:00]),
  #       build(:pageview, timestamp: ~N[2019-01-05 00:00:00]),
  #       build(:pageview, timestamp: ~N[2019-01-05 00:00:00]),
  #       build(:pageview, timestamp: ~N[2019-01-31 00:00:00])
  #     ])

  #     conn =
  #       get(
  #         conn,
  #         "/api/stats/#{site.domain}/main-graph?period=month&date=2020-01-01&comparison=year_over_year"
  #       )

  #     assert %{"plot" => plot, "comparison_plot" => comparison_plot} = json_response(conn, 200)

  #     assert 1 == Enum.at(plot, 0)
  #     assert 2 == Enum.at(comparison_plot, 0)

  #     assert 1 == Enum.at(plot, 4)
  #     assert 2 == Enum.at(comparison_plot, 4)

  #     assert 1 == Enum.at(plot, 30)
  #     assert 1 == Enum.at(comparison_plot, 30)
  #   end

  #   test "fill in gaps when custom comparison period is larger than original query", %{
  #     conn: conn,
  #     site: site
  #   } do
  #     populate_stats(site, [
  #       build(:pageview, timestamp: ~N[2020-01-01 00:00:00]),
  #       build(:pageview, timestamp: ~N[2020-01-05 00:00:00]),
  #       build(:pageview, timestamp: ~N[2020-01-30 00:00:00])
  #     ])

  #     conn =
  #       get(
  #         conn,
  #         "/api/stats/#{site.domain}/main-graph?period=month&date=2020-01-01&comparison=custom&compare_from=2022-01-01&compare_to=2022-06-01"
  #       )

  #     assert %{"labels" => labels, "comparison_plot" => comparison_labels} =
  #              json_response(conn, 200)

  #     assert length(labels) == length(comparison_labels)
  #     assert "__blank__" == List.last(labels)
  #   end

  #   test "compares imported data and native data together", %{conn: conn, site: site} do
  #     populate_stats(site, [
  #       build(:imported_visitors, date: ~D[2020-01-02]),
  #       build(:imported_visitors, date: ~D[2020-01-02]),
  #       build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
  #       build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
  #       build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
  #       build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
  #     ])

  #     conn =
  #       get(
  #         conn,
  #         "/api/stats/#{site.domain}/main-graph?period=year&date=2021-01-01&with_imported=true&comparison=year_over_year&interval=month"
  #       )

  #     assert %{
  #              "plot" => plot,
  #              "comparison_plot" => comparison_plot,
  #              "imports_exist" => true,
  #              "includes_imported" => true
  #            } = json_response(conn, 200)

  #     assert 4 == Enum.sum(plot)
  #     assert 2 == Enum.sum(comparison_plot)
  #   end

  #   test "does not return imported data when with_imported is set to false when comparing", %{
  #     conn: conn,
  #     site: site
  #   } do
  #     populate_stats(site, [
  #       build(:imported_visitors, date: ~D[2020-01-02]),
  #       build(:imported_visitors, date: ~D[2020-01-02]),
  #       build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
  #       build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
  #       build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
  #       build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
  #     ])

  #     conn =
  #       get(
  #         conn,
  #         "/api/stats/#{site.domain}/main-graph?period=year&date=2021-01-01&with_imported=false&comparison=year_over_year&interval=month"
  #       )

  #     assert %{
  #              "plot" => plot,
  #              "comparison_plot" => comparison_plot,
  #              "imports_exist" => true,
  #              "includes_imported" => false
  #            } = json_response(conn, 200)

  #     assert 4 == Enum.sum(plot)
  #     assert 0 == Enum.sum(comparison_plot)
  #   end

  #   test "plots conversion rate previous period comparison", %{site: site, conn: conn} do
  #     insert(:goal, site: site, event_name: "Signup")

  #     populate_stats(site, [
  #       build(:event, name: "Signup", timestamp: ~N[2021-01-01 00:01:00]),
  #       build(:pageview, timestamp: ~N[2021-01-01 00:01:00]),
  #       build(:pageview, timestamp: ~N[2021-01-01 00:01:00]),
  #       build(:event, name: "Signup", timestamp: ~N[2021-01-08 00:01:00]),
  #       build(:pageview, timestamp: ~N[2021-01-08 00:01:00])
  #     ])

  #     filters = Jason.encode!(%{goal: "Signup"})

  #     conn =
  #       get(
  #         conn,
  #         "/api/stats/#{site.domain}/main-graph?period=7d&date=2021-01-14&comparison=previous_period&metric=conversion_rate&filters=#{filters}"
  #       )

  #     assert %{
  #              "plot" => this_week_plot,
  #              "comparison_plot" => last_week_plot,
  #              "imports_exist" => true,
  #              "includes_imported" => false
  #            } = json_response(conn, 200)

  #     assert this_week_plot == [50.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
  #     assert last_week_plot == [33.3, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
  #   end
  # end

  # describe "GET /api/stats/main-graph - events (total conversions) plot" do
  #   setup [:create_user, :log_in, :create_new_site]

  #   test "returns 400 when the `events` metric is queried without a goal filter", %{
  #     conn: conn,
  #     site: site
  #   } do
  #     conn =
  #       get(
  #         conn,
  #         "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&metric=events"
  #       )

  #     assert %{"error" => error} = json_response(conn, 400)
  #     assert error =~ "`events` can only be queried with a goal filter"
  #   end

  #   test "displays total conversions per hour with previous day comparison plot", %{
  #     conn: conn,
  #     site: site
  #   } do
  #     insert(:goal, site: site, event_name: "Signup")

  #     populate_stats(site, [
  #       build(:event, name: "Different", timestamp: ~N[2021-01-10 05:00:00]),
  #       build(:event, name: "Signup", timestamp: ~N[2021-01-10 05:00:00]),
  #       build(:event, name: "Signup", timestamp: ~N[2021-01-10 05:00:00]),
  #       build(:event, name: "Signup", timestamp: ~N[2021-01-10 19:00:00]),
  #       build(:pageview, timestamp: ~N[2021-01-10 19:00:00]),
  #       build(:event, name: "Signup", timestamp: ~N[2021-01-11 04:00:00]),
  #       build(:event, name: "Signup", timestamp: ~N[2021-01-11 05:00:00]),
  #       build(:event, name: "Signup", timestamp: ~N[2021-01-11 18:00:00])
  #     ])

  #     filters = Jason.encode!(%{goal: "Signup"})

  #     conn =
  #       get(
  #         conn,
  #         "/api/stats/#{site.domain}/main-graph?period=day&date=2021-01-11&metric=events&filters=#{filters}&comparison=previous_period"
  #       )

  #     assert %{"plot" => curr, "comparison_plot" => prev} = json_response(conn, 200)
  #     assert [0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0] = prev
  #     assert [0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0] = curr
  #   end

  #   test "displays conversions per month with 12mo comparison plot", %{
  #     conn: conn,
  #     site: site
  #   } do
  #     insert(:goal, site: site, event_name: "Signup")

  #     populate_stats(site, [
  #       build(:event, name: "Different", timestamp: ~N[2020-01-10 00:00:00]),
  #       build(:event, name: "Signup", timestamp: ~N[2020-02-10 00:00:00]),
  #       build(:event, name: "Signup", timestamp: ~N[2020-03-10 00:00:00]),
  #       build(:event, name: "Signup", timestamp: ~N[2020-04-10 00:00:00]),
  #       build(:pageview, timestamp: ~N[2021-05-10 00:00:00]),
  #       build(:event, name: "Signup", timestamp: ~N[2021-06-11 04:00:00]),
  #       build(:event, name: "Signup", timestamp: ~N[2021-07-11 00:00:00]),
  #       build(:event, name: "Signup", timestamp: ~N[2021-08-11 00:00:00])
  #     ])

  #     filters = Jason.encode!(%{goal: "Signup"})

  #     conn =
  #       get(
  #         conn,
  #         "/api/stats/#{site.domain}/main-graph?period=12mo&date=2021-12-11&metric=events&filters=#{filters}&comparison=previous_period"
  #       )

  #     assert %{"plot" => curr, "comparison_plot" => prev} = json_response(conn, 200)
  #     assert [0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0] = prev
  #     assert [0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0] = curr
  #   end
  # end
end
