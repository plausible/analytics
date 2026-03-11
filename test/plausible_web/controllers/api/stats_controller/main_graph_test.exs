defmodule PlausibleWeb.Api.StatsController.MainGraphTest do
  use PlausibleWeb.ConnCase

  @user_id Enum.random(1000..9999)

  defp do_query(conn, site, params, opts \\ []) do
    now = Keyword.get(opts, :now)

    conn
    |> Plug.Conn.put_private(:now, now)
    |> post("/api/stats/#{site.domain}/query", params)
    |> json_response(200)
  end

  defp do_query_fail(conn, site, params) do
    conn
    |> post("/api/stats/#{site.domain}/query", params)
  end

  describe "plot" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "displays pageviews for the last 30 minutes in realtime graph", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2024-04-02 03:20:46])
      ])

      response =
        do_query(
          conn,
          site,
          %{
            "date_range" => "realtime_30m",
            "metrics" => ["pageviews"],
            "dimensions" => ["time:minute"],
            "include" => %{"time_labels" => true}
          },
          now: ~U[2024-04-02 03:27:30Z]
        )

      %{"results" => results, "meta" => meta} = response

      assert length(meta["time_labels"]) == 30
      assert List.first(meta["time_labels"]) == "2024-04-02 02:57:00"
      assert List.last(meta["time_labels"]) == "2024-04-02 03:26:00"
      assert [%{"dimensions" => ["2024-04-02 03:20:00"], "metrics" => [1]}] = results
    end

    test "displays pageviews for the last 30 minutes for a non-UTC timezone site", %{
      conn: conn,
      site: site
    } do
      Plausible.Site.changeset(site, %{timezone: "Europe/Tallinn"})
      |> Plausible.Repo.update()

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2024-04-02 03:20:46])
      ])

      response =
        do_query(
          conn,
          site,
          %{
            "date_range" => "realtime_30m",
            "metrics" => ["pageviews"],
            "dimensions" => ["time:minute"],
            "include" => %{"time_labels" => true}
          },
          now: ~U[2024-04-02 03:27:30Z]
        )

      %{"results" => results, "meta" => meta} = response

      assert length(meta["time_labels"]) == 30
      assert List.first(meta["time_labels"]) == "2024-04-02 05:57:00"
      assert List.last(meta["time_labels"]) == "2024-04-02 06:26:00"
      assert [%{"dimensions" => ["2024-04-02 06:20:00"], "metrics" => [1]}] = results
    end

    test "displays pageviews for a day", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 23:00:00])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "day",
          "relative_date" => "2021-01-01",
          "metrics" => ["pageviews"],
          "dimensions" => ["time:hour"]
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01 00:00:00"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-01 23:00:00"], "metrics" => [1]}
             ]
    end

    test "returns empty plot with no native data and recently imported from ga in realtime graph",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors, date: Date.utc_today()),
        build(:imported_visitors, date: Date.utc_today())
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "realtime_30m",
          "metrics" => ["visitors"],
          "dimensions" => ["time:minute"],
          "include" => %{"imports" => true, "time_labels" => true}
        })

      assert length(response["meta"]["time_labels"]) == 30
      assert response["results"] == []
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

      response =
        do_query(conn, site, %{
          "date_range" => "day",
          "relative_date" => "2021-01-01",
          "metrics" => ["visitors"],
          "dimensions" => ["time:hour"],
          "include" => %{"imports" => true}
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01 00:00:00"], "metrics" => [1]}
             ]
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

      response =
        do_query(conn, site, %{
          "date_range" => "day",
          "relative_date" => "2021-01-01",
          "metrics" => ["visitors"],
          "dimensions" => ["time:hour"]
        })

      # Expecting pageview to show at 1am CET
      assert response["results"] == [
               %{"dimensions" => ["2021-01-01 01:00:00"], "metrics" => [1]}
             ]
    end

    test "displays visitors for a month", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-01-01",
          "metrics" => ["visitors"],
          "include" => %{"time_labels" => true},
          "dimensions" => ["time:day"]
        })

      assert length(response["meta"]["time_labels"]) == 31

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-31"], "metrics" => [1]}
             ]
    end

    test "displays visitors for last 28d", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-28 00:00:00])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "28d",
          "relative_date" => "2021-01-29",
          "metrics" => ["visitors"],
          "dimensions" => ["time:day"],
          "include" => %{"time_labels" => true}
        })

      assert length(response["meta"]["time_labels"]) == 28

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-28"], "metrics" => [1]}
             ]
    end

    test "displays visitors for last 91d", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-16 00:00:00]),
        build(:pageview, timestamp: ~N[2021-04-16 00:00:00])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "91d",
          "relative_date" => "2021-04-17",
          "metrics" => ["visitors"],
          "dimensions" => ["time:day"]
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-16"], "metrics" => [1]},
               %{"dimensions" => ["2021-04-16"], "metrics" => [1]}
             ]
    end

    test "displays visitors for a month with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00]),
        build(:imported_visitors, date: ~D[2021-01-01]),
        build(:imported_visitors, date: ~D[2021-01-31])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-01-01",
          "metrics" => ["visitors"],
          "dimensions" => ["time:day"],
          "include" => %{"imports" => true}
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [2]},
               %{"dimensions" => ["2021-01-31"], "metrics" => [2]}
             ]
    end

    test "displays visitors for a month with only imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors, date: ~D[2021-01-01]),
        build(:imported_visitors, date: ~D[2021-01-31])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-01-01",
          "metrics" => ["visitors"],
          "dimensions" => ["time:day"],
          "include" => %{"imports" => true}
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-31"], "metrics" => [1]}
             ]
    end

    test "displays visitors for a month with imported data and filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00], pathname: "/pageA"),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00], pathname: "/pageA"),
        build(:imported_visitors, date: ~D[2021-01-01]),
        build(:imported_visitors, date: ~D[2021-01-31])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-01-01",
          "metrics" => ["visitors"],
          "dimensions" => ["time:day"],
          "filters" => [["is", "event:page", ["/pageA"]]],
          "include" => %{"imports" => true}
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-31"], "metrics" => [1]}
             ]
    end

    test "displays visitors for 6 months with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-12-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-05-31 00:00:00]),
        build(:imported_visitors, date: ~D[2020-12-01]),
        build(:imported_visitors, date: ~D[2021-05-31])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "6mo",
          "relative_date" => "2021-06-30",
          "metrics" => ["visitors"],
          "dimensions" => ["time:month"],
          "include" => %{"imports" => true, "time_labels" => true}
        })

      assert response["meta"]["time_labels"] == [
               "2020-12-01",
               "2021-01-01",
               "2021-02-01",
               "2021-03-01",
               "2021-04-01",
               "2021-05-01"
             ]

      assert response["results"] == [
               %{"dimensions" => ["2020-12-01"], "metrics" => [2]},
               %{"dimensions" => ["2021-05-01"], "metrics" => [2]}
             ]
    end

    test "displays visitors for 6 months with only imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors, date: ~D[2020-12-01]),
        build(:imported_visitors, date: ~D[2021-05-31])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "6mo",
          "relative_date" => "2021-06-30",
          "metrics" => ["visitors"],
          "dimensions" => ["time:month"],
          "include" => %{"imports" => true}
        })

      assert response["results"] == [
               %{"dimensions" => ["2020-12-01"], "metrics" => [1]},
               %{"dimensions" => ["2021-05-01"], "metrics" => [1]}
             ]
    end

    test "displays visitors for 12 months with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-12-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-11-30 00:00:00]),
        build(:imported_visitors, date: ~D[2020-12-01]),
        build(:imported_visitors, date: ~D[2021-11-30])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "12mo",
          "relative_date" => "2021-12-31",
          "metrics" => ["visitors"],
          "dimensions" => ["time:month"],
          "include" => %{"imports" => true, "time_labels" => true}
        })

      assert length(response["meta"]["time_labels"]) == 12

      assert response["results"] == [
               %{"dimensions" => ["2020-12-01"], "metrics" => [2]},
               %{"dimensions" => ["2021-11-01"], "metrics" => [2]}
             ]
    end

    test "displays visitors for 12 months with only imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors, date: ~D[2020-12-01]),
        build(:imported_visitors, date: ~D[2021-11-30])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "12mo",
          "relative_date" => "2021-12-31",
          "metrics" => ["visitors"],
          "dimensions" => ["time:month"],
          "include" => %{"imports" => true, "time_labels" => true}
        })

      assert response["meta"]["time_labels"] == [
               "2020-12-01",
               "2021-01-01",
               "2021-02-01",
               "2021-03-01",
               "2021-04-01",
               "2021-05-01",
               "2021-06-01",
               "2021-07-01",
               "2021-08-01",
               "2021-09-01",
               "2021-10-01",
               "2021-11-01"
             ]

      assert response["results"] == [
               %{"dimensions" => ["2020-12-01"], "metrics" => [1]},
               %{"dimensions" => ["2021-11-01"], "metrics" => [1]}
             ]
    end

    test "displays visitors for calendar year with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-12-31 00:00:00]),
        build(:imported_visitors, date: ~D[2021-01-01]),
        build(:imported_visitors, date: ~D[2021-12-31])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "year",
          "relative_date" => "2021-12-31",
          "metrics" => ["visitors"],
          "dimensions" => ["time:month"],
          "include" => %{"imports" => true}
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [2]},
               %{"dimensions" => ["2021-12-01"], "metrics" => [2]}
             ]
    end

    test "displays visitors for calendar year with only imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors, date: ~D[2021-01-01]),
        build(:imported_visitors, date: ~D[2021-12-31])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "year",
          "relative_date" => "2021-12-31",
          "metrics" => ["visitors"],
          "dimensions" => ["time:month"],
          "include" => %{"imports" => true}
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [1]},
               %{"dimensions" => ["2021-12-01"], "metrics" => [1]}
             ]
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

      response =
        do_query(
          conn,
          site,
          %{
            "date_range" => "all",
            "metrics" => ["visitors"],
            "dimensions" => ["time:month"],
            "include" => %{"imports" => true, "time_labels" => true}
          },
          now: ~U[2022-03-15 10:00:00Z]
        )

      assert length(response["meta"]["time_labels"]) == 27
      assert List.last(response["meta"]["time_labels"]) == "2022-03-01"

      assert response["results"] == [
               %{"dimensions" => ["2020-01-01"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-01"], "metrics" => [1]},
               %{"dimensions" => ["2021-12-01"], "metrics" => [1]}
             ]
    end
  end

  describe "default labels" do
    setup [:create_user, :log_in, :create_site]

    test "shows last 30 days", %{conn: conn, site: site} do
      response =
        do_query(conn, site, %{
          "date_range" => "30d",
          "metrics" => ["visitors"],
          "dimensions" => ["time:day"],
          "include" => %{"time_labels" => true}
        })

      labels = response["meta"]["time_labels"]

      first = Date.utc_today() |> Date.shift(day: -30) |> Date.to_iso8601()
      last = Date.utc_today() |> Date.shift(day: -1) |> Date.to_iso8601()
      assert List.first(labels) == first
      assert List.last(labels) == last
    end

    test "shows last 7 days", %{conn: conn, site: site} do
      response =
        do_query(conn, site, %{
          "date_range" => "7d",
          "metrics" => ["visitors"],
          "dimensions" => ["time:day"],
          "include" => %{"time_labels" => true}
        })

      labels = response["meta"]["time_labels"]

      first = Date.utc_today() |> Date.shift(day: -7) |> Date.to_iso8601()
      last = Date.utc_today() |> Date.shift(day: -1) |> Date.to_iso8601()
      assert List.first(labels) == first
      assert List.last(labels) == last
    end
  end

  describe "pageviews plot" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "displays pageviews for a month", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-01-01",
          "metrics" => ["pageviews"],
          "dimensions" => ["time:day"]
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [2]},
               %{"dimensions" => ["2021-01-31"], "metrics" => [1]}
             ]
    end

    test "displays pageviews for a month with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00]),
        build(:imported_visitors, date: ~D[2021-01-01]),
        build(:imported_visitors, date: ~D[2021-01-31])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-01-01",
          "metrics" => ["pageviews"],
          "dimensions" => ["time:day"],
          "include" => %{"imports" => true}
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [2]},
               %{"dimensions" => ["2021-01-31"], "metrics" => [2]}
             ]
    end

    test "displays pageviews for a month with only imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors, date: ~D[2021-01-01]),
        build(:imported_visitors, date: ~D[2021-01-31])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-01-01",
          "metrics" => ["pageviews"],
          "dimensions" => ["time:day"],
          "include" => %{"imports" => true}
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-31"], "metrics" => [1]}
             ]
    end
  end

  describe "views_per_visit plot" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "views_per_visit for 28 days in weekly buckets (native data only)", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, user_id: 1, timestamp: ~N[2021-01-04 00:00:00]),
        build(:pageview, user_id: 1, timestamp: ~N[2021-01-04 00:05:00]),
        build(:pageview, user_id: 2, timestamp: ~N[2021-01-18 00:00:00]),
        build(:pageview, user_id: 2, timestamp: ~N[2021-01-18 00:05:00]),
        build(:pageview, user_id: 2, timestamp: ~N[2021-01-18 00:10:00])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "28d",
          "relative_date" => "2021-01-29",
          "metrics" => ["views_per_visit"],
          "dimensions" => ["time:week"]
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-04"], "metrics" => [2.0]},
               %{"dimensions" => ["2021-01-18"], "metrics" => [3.0]}
             ]
    end

    test "views_per_visit for a year in monthly buckets (with imported data)", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        # January 2021 - only imported
        build(:imported_visitors, date: ~D[2021-01-01], visits: 6, pageviews: 7),
        # March 2021 - imported + native combined
        build(:imported_visitors, date: ~D[2021-03-01], visits: 1, pageviews: 4),
        build(:pageview, user_id: 1, timestamp: ~N[2021-03-15 00:00:00]),
        build(:pageview, user_id: 1, timestamp: ~N[2021-03-15 00:05:00]),
        # September 2021 - only native
        build(:pageview, user_id: 2, timestamp: ~N[2021-09-01 00:00:00])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "year",
          "relative_date" => "2021-01-01",
          "metrics" => ["views_per_visit"],
          "dimensions" => ["time:month"],
          "include" => %{"imports" => true}
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [1.17]},
               %{"dimensions" => ["2021-03-01"], "metrics" => [3.0]},
               %{"dimensions" => ["2021-09-01"], "metrics" => [1.0]}
             ]
    end
  end

  describe "visitors plot" do
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

      response =
        do_query(conn, site, %{
          "date_range" => "day",
          "relative_date" => "2021-01-01",
          "metrics" => ["visitors"],
          "dimensions" => ["time:hour"]
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01 00:00:00"], "metrics" => [2]}
             ]
    end

    test "displays visitors realtime with visits spanning multiple minutes", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2023-09-10 15:15:00], user_id: 1),
        build(:pageview, timestamp: ~N[2023-09-10 15:30:00], user_id: 1),
        build(:pageview, timestamp: ~N[2023-09-10 15:25:00], user_id: 2),
        build(:pageview, timestamp: ~N[2023-09-10 15:35:00], user_id: 2),
        build(:pageview, timestamp: ~N[2023-09-10 15:45:00], user_id: 3),
        build(:pageview, timestamp: ~N[2023-09-10 15:47:00], user_id: 3)
      ])

      response =
        do_query(
          conn,
          site,
          %{
            "date_range" => "realtime_30m",
            "metrics" => ["visitors"],
            "dimensions" => ["time:minute"]
          },
          now: ~U[2023-09-10 15:50:01Z]
        )

      assert response["results"] == [
               %{"dimensions" => ["2023-09-10 15:20:00"], "metrics" => [1]},
               %{"dimensions" => ["2023-09-10 15:21:00"], "metrics" => [1]},
               %{"dimensions" => ["2023-09-10 15:22:00"], "metrics" => [1]},
               %{"dimensions" => ["2023-09-10 15:23:00"], "metrics" => [1]},
               %{"dimensions" => ["2023-09-10 15:24:00"], "metrics" => [1]},
               %{"dimensions" => ["2023-09-10 15:25:00"], "metrics" => [2]},
               %{"dimensions" => ["2023-09-10 15:26:00"], "metrics" => [2]},
               %{"dimensions" => ["2023-09-10 15:27:00"], "metrics" => [2]},
               %{"dimensions" => ["2023-09-10 15:28:00"], "metrics" => [2]},
               %{"dimensions" => ["2023-09-10 15:29:00"], "metrics" => [2]},
               %{"dimensions" => ["2023-09-10 15:30:00"], "metrics" => [2]},
               %{"dimensions" => ["2023-09-10 15:31:00"], "metrics" => [1]},
               %{"dimensions" => ["2023-09-10 15:32:00"], "metrics" => [1]},
               %{"dimensions" => ["2023-09-10 15:33:00"], "metrics" => [1]},
               %{"dimensions" => ["2023-09-10 15:34:00"], "metrics" => [1]},
               %{"dimensions" => ["2023-09-10 15:35:00"], "metrics" => [1]},
               %{"dimensions" => ["2023-09-10 15:45:00"], "metrics" => [1]},
               %{"dimensions" => ["2023-09-10 15:46:00"], "metrics" => [1]},
               %{"dimensions" => ["2023-09-10 15:47:00"], "metrics" => [1]}
             ]
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

      response =
        do_query(conn, site, %{
          "date_range" => "day",
          "relative_date" => "2021-01-01",
          "metrics" => ["visitors"],
          "dimensions" => ["time:hour"]
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01 00:00:00"], "metrics" => [2]},
               %{"dimensions" => ["2021-01-01 01:00:00"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-01 02:00:00"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-01 23:00:00"], "metrics" => [1]}
             ]
    end

    test "displays visitors per day with sessions being counted only in the last time bucket they were active in",
         %{
           conn: conn,
           site: site
         } do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-12-31 23:45:00], user_id: 1),
        build(:pageview, timestamp: ~N[2021-01-01 00:10:00], user_id: 1),
        build(:pageview, timestamp: ~N[2021-01-02 23:45:00], user_id: 2),
        build(:pageview, timestamp: ~N[2021-01-03 00:10:00], user_id: 2),
        build(:pageview, timestamp: ~N[2021-01-03 23:45:00], user_id: 3),
        build(:pageview, timestamp: ~N[2021-01-04 00:10:00], user_id: 3),
        build(:pageview, timestamp: ~N[2021-01-07 23:45:00], user_id: 4),
        build(:pageview, timestamp: ~N[2021-01-08 00:10:00], user_id: 4)
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "7d",
          "relative_date" => "2021-01-08",
          "metrics" => ["visitors"],
          "dimensions" => ["time:day"]
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-03"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-04"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-07"], "metrics" => [1]}
             ]
    end

    test "displays visitors per week with sessions being counted only in the last time bucket they were active in",
         %{
           conn: conn,
           site: site
         } do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-12-31 23:45:00], user_id: 1),
        build(:pageview, timestamp: ~N[2021-01-01 00:10:00], user_id: 1),
        build(:pageview, timestamp: ~N[2021-01-03 23:45:00], user_id: 2),
        build(:pageview, timestamp: ~N[2021-01-04 00:10:00], user_id: 2),
        build(:pageview, timestamp: ~N[2021-01-31 23:45:00], user_id: 3),
        build(:pageview, timestamp: ~N[2021-02-01 00:05:00], user_id: 3)
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-01-01",
          "metrics" => ["visitors"],
          "dimensions" => ["time:week"]
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-04"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-25"], "metrics" => [1]}
             ]
    end
  end

  describe "scroll_depth plot" do
    setup [:create_user, :log_in, :create_site]

    test "returns 400 when scroll_depth is queried without a page filter", %{
      conn: conn,
      site: site
    } do
      response =
        do_query_fail(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-01-01",
          "metrics" => ["scroll_depth"],
          "dimensions" => ["time:day"]
        })

      assert %{"error" => error} = json_response(response, 400)
      assert error =~ "can only be queried with event:page filters or dimensions"
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

      response =
        do_query(conn, site, %{
          "date_range" => "7d",
          "relative_date" => "2020-01-08",
          "metrics" => ["scroll_depth"],
          "dimensions" => ["time:day"],
          "filters" => [["is", "event:page", ["/"]]]
        })

      assert response["results"] == [
               %{"dimensions" => ["2020-01-01"], "metrics" => [40]},
               %{"dimensions" => ["2020-01-02"], "metrics" => [20]}
             ]
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

      response =
        do_query(conn, site, %{
          "date_range" => "7d",
          "relative_date" => "2020-01-08",
          "metrics" => ["scroll_depth"],
          "dimensions" => ["time:day"],
          "filters" => [["is", "event:page", ["/"]]],
          "include" => %{"imports" => true}
        })

      assert response["results"] == [
               %{"dimensions" => ["2020-01-01"], "metrics" => [40]},
               %{"dimensions" => ["2020-01-02"], "metrics" => [30]},
               %{"dimensions" => ["2020-01-03"], "metrics" => [90]}
             ]
    end
  end

  describe "conversion_rate plot" do
    setup [:create_user, :log_in, :create_site]

    test "returns 400 when conversion rate is queried without a goal filter", %{
      conn: conn,
      site: site
    } do
      response =
        do_query_fail(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-01-01",
          "metrics" => ["conversion_rate"],
          "dimensions" => ["time:day"]
        })

      assert %{"error" => error} = json_response(response, 400)
      assert error =~ "can only be queried with event:goal filters or dimensions"
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

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-01-01",
          "metrics" => ["group_conversion_rate"],
          "dimensions" => ["time:day"],
          "filters" => [["is", "event:goal", ["Signup"]]]
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [33.33]},
               %{"dimensions" => ["2021-01-31"], "metrics" => [50.0]}
             ]
    end
  end

  describe "events (total conversions) plot" do
    setup [:create_user, :log_in, :create_site]

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

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-01-01",
          "metrics" => ["events"],
          "dimensions" => ["time:day"],
          "filters" => [["is", "event:goal", ["Signup"]]]
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [2]},
               %{"dimensions" => ["2021-01-31"], "metrics" => [3]}
             ]
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

      response =
        do_query(conn, site, %{
          "date_range" => "day",
          "relative_date" => "2021-01-11",
          "metrics" => ["events"],
          "dimensions" => ["time:hour"],
          "filters" => [["is", "event:goal", ["Signup"]]],
          "include" => %{"compare" => "previous_period"}
        })

      results = response["results"]
      curr = Enum.map(results, fn r -> List.first(r["metrics"]) end)
      prev = Enum.map(results, fn r -> List.first(r["comparison"]["metrics"]) end)

      assert prev == [0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0]
      assert curr == [0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0]
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

      response =
        do_query(conn, site, %{
          "date_range" => "12mo",
          "relative_date" => "2021-12-11",
          "metrics" => ["events"],
          "dimensions" => ["time:month"],
          "filters" => [["is", "event:goal", ["Signup"]]],
          "include" => %{"compare" => "previous_period"}
        })

      results = response["results"]
      curr = Enum.map(results, fn r -> List.first(r["metrics"]) end)
      prev = Enum.map(results, fn r -> List.first(r["comparison"]["metrics"]) end)

      assert prev == [0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0]
      assert curr == [0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0]
    end
  end

  describe "bounce_rate plot" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "displays bounce_rate for a month", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-03 00:00:00], user_id: 1),
        build(:pageview, timestamp: ~N[2021-01-03 00:10:00], user_id: 1),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-01-01",
          "metrics" => ["bounce_rate"],
          "dimensions" => ["time:day"]
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-03"], "metrics" => [0]},
               %{"dimensions" => ["2021-01-31"], "metrics" => [100]}
             ]
    end

    test "displays bounce rate for a month with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00]),
        build(:imported_visitors, visits: 1, bounces: 0, date: ~D[2021-01-01]),
        build(:imported_visitors, visits: 1, bounces: 1, date: ~D[2021-01-31])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-01-01",
          "metrics" => ["bounce_rate"],
          "dimensions" => ["time:day"],
          "include" => %{"imports" => true}
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [50]},
               %{"dimensions" => ["2021-01-31"], "metrics" => [100]}
             ]
    end

    test "displays bounce rate for a month with only imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors, visits: 1, bounces: 0, date: ~D[2021-01-01]),
        build(:imported_visitors, visits: 1, bounces: 1, date: ~D[2021-01-31])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-01-01",
          "metrics" => ["bounce_rate"],
          "dimensions" => ["time:day"],
          "include" => %{"imports" => true}
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [0]},
               %{"dimensions" => ["2021-01-31"], "metrics" => [100]}
             ]
    end
  end

  describe "visit_duration plot" do
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

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-01-01",
          "metrics" => ["visit_duration"],
          "dimensions" => ["time:day"]
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-31"], "metrics" => [300]}
             ]
    end

    test "displays visit_duration for a month with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:10:00]),
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:15:00]),
        build(:imported_visitors, visits: 1, visit_duration: 100, date: ~D[2021-01-01])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-01-01",
          "metrics" => ["visit_duration"],
          "dimensions" => ["time:day"],
          "include" => %{"imports" => true}
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [200]}
             ]
    end

    test "displays visit_duration for a month with only imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_visitors, visits: 1, visit_duration: 100, date: ~D[2021-01-01])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-01-01",
          "metrics" => ["visit_duration"],
          "dimensions" => ["time:day"],
          "include" => %{"imports" => true}
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [100]}
             ]
    end
  end

  describe "varying intervals" do
    setup [:create_user, :log_in, :create_site]

    test "displays visitors for 6mo on a day scale", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-12-01 00:00:00]),
        build(:pageview, timestamp: ~N[2020-12-15 00:00:00]),
        build(:pageview, timestamp: ~N[2020-12-15 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-15 00:00:00]),
        build(:pageview, timestamp: ~N[2021-05-31 01:00:00])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "6mo",
          "relative_date" => "2021-06-01",
          "metrics" => ["visitors"],
          "dimensions" => ["time:day"],
          "include" => %{"time_labels" => true}
        })

      assert length(response["meta"]["time_labels"]) == 182

      assert response["results"] == [
               %{"dimensions" => ["2020-12-01"], "metrics" => [1]},
               %{"dimensions" => ["2020-12-15"], "metrics" => [2]},
               %{"dimensions" => ["2021-01-15"], "metrics" => [1]},
               %{"dimensions" => ["2021-05-31"], "metrics" => [1]}
             ]
    end

    test "displays visitors for a custom period on a monthly scale", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-15 00:00:00]),
        build(:pageview, timestamp: ~N[2021-02-15 00:00:00]),
        build(:pageview, timestamp: ~N[2021-06-01 00:00:00])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => ["2021-01-01", "2021-06-30"],
          "metrics" => ["visitors"],
          "dimensions" => ["time:month"]
        })

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [2]},
               %{"dimensions" => ["2021-02-01"], "metrics" => [1]},
               %{"dimensions" => ["2021-06-01"], "metrics" => [1]}
             ]
    end

    test "returns error when the interval is not valid", %{
      conn: conn,
      site: site
    } do
      response =
        do_query_fail(conn, site, %{
          "date_range" => "day",
          "relative_date" => "2021-01-01",
          "metrics" => ["visitors"],
          "dimensions" => ["time:biweekly"]
        })

      assert %{"error" => error} = json_response(response, 400)
      assert error =~ "Invalid dimensions"
    end

    test "displays visitors for a month on a weekly scale", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:15:01]),
        build(:pageview, timestamp: ~N[2021-01-05 00:15:02])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-01-01",
          "metrics" => ["visitors"],
          "dimensions" => ["time:week"],
          "include" => %{"time_labels" => true}
        })

      assert length(response["meta"]["time_labels"]) == 5

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [2]},
               %{"dimensions" => ["2021-01-04"], "metrics" => [1]}
             ]
    end

    test "shows imperfect week-split month on week scale with partial week indicators", %{
      conn: conn,
      site: site
    } do
      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-09-01",
          "metrics" => ["visitors"],
          "dimensions" => ["time:week"],
          "include" => %{"time_labels" => true, "partial_time_labels" => true}
        })

      assert response["meta"]["time_labels"] == [
               "2021-09-01",
               "2021-09-06",
               "2021-09-13",
               "2021-09-20",
               "2021-09-27"
             ]

      assert response["meta"]["partial_time_labels"] == ["2021-09-01", "2021-09-27"]
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

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2023-03-01",
          "metrics" => ["visitors"],
          "dimensions" => ["time:week"],
          "include" => %{"time_labels" => true}
        })

      assert List.first(response["meta"]["time_labels"]) == "2023-03-01"

      assert response["results"] == [
               %{"metrics" => [1], "dimensions" => ["2023-03-01"]}
             ]
    end

    test "shows half-perfect week-split month on week scale with partial week indicators", %{
      conn: conn,
      site: site
    } do
      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-10-01",
          "metrics" => ["visitors"],
          "dimensions" => ["time:week"],
          "include" => %{"time_labels" => true, "partial_time_labels" => true}
        })

      assert response["meta"]["time_labels"] == [
               "2021-10-01",
               "2021-10-04",
               "2021-10-11",
               "2021-10-18",
               "2021-10-25"
             ]

      assert response["meta"]["partial_time_labels"] == ["2021-10-01"]
    end

    test "shows perfect week-split range on week scale with full week indicators for custom period",
         %{
           conn: conn,
           site: site
         } do
      response =
        do_query(conn, site, %{
          "date_range" => ["2020-12-21", "2021-02-07"],
          "metrics" => ["visitors"],
          "dimensions" => ["time:week"],
          "include" => %{"time_labels" => true, "partial_time_labels" => true}
        })

      assert response["meta"]["time_labels"] == [
               "2020-12-21",
               "2020-12-28",
               "2021-01-04",
               "2021-01-11",
               "2021-01-18",
               "2021-01-25",
               "2021-02-01"
             ]

      assert response["meta"]["partial_time_labels"] == []
    end

    test "shows imperfect week-split for last 28d with full week indicators", %{
      conn: conn,
      site: site
    } do
      response =
        do_query(conn, site, %{
          "date_range" => "28d",
          "relative_date" => "2021-10-30",
          "metrics" => ["visitors"],
          "dimensions" => ["time:week"],
          "include" => %{"time_labels" => true, "partial_time_labels" => true}
        })

      assert response["meta"]["time_labels"] == [
               "2021-10-02",
               "2021-10-04",
               "2021-10-11",
               "2021-10-18",
               "2021-10-25"
             ]

      assert response["meta"]["partial_time_labels"] == ["2021-10-02", "2021-10-25"]
    end

    test "shows imperfect month-split for custom period with full month indicators", %{
      conn: conn,
      site: site
    } do
      response =
        do_query(conn, site, %{
          "date_range" => ["2021-09-06", "2021-12-13"],
          "metrics" => ["visitors"],
          "dimensions" => ["time:month"],
          "include" => %{"time_labels" => true, "partial_time_labels" => true}
        })

      assert response["meta"]["time_labels"] == [
               "2021-09-01",
               "2021-10-01",
               "2021-11-01",
               "2021-12-01"
             ]

      assert response["meta"]["partial_time_labels"] == ["2021-09-01", "2021-12-01"]
    end

    test "shows perfect month-split for last 91d with full month indicators", %{
      conn: conn,
      site: site
    } do
      response =
        do_query(conn, site, %{
          "date_range" => "91d",
          "relative_date" => "2021-12-01",
          "metrics" => ["visitors"],
          "dimensions" => ["time:month"],
          "include" => %{"time_labels" => true, "partial_time_labels" => true}
        })

      assert response["meta"]["time_labels"] == ["2021-09-01", "2021-10-01", "2021-11-01"]

      assert response["meta"]["partial_time_labels"] == []
    end

    test "returns stats for a day with a minute interval", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2023-03-01 12:00:00])
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "day",
          "relative_date" => "2023-03-01",
          "metrics" => ["visitors"],
          "dimensions" => ["time:minute"],
          "include" => %{"time_labels" => true}
        })

      labels = response["meta"]["time_labels"]

      assert length(labels) == 24 * 60
      assert List.first(labels) == "2023-03-01 00:00:00"
      assert Enum.at(labels, 1) == "2023-03-01 00:01:00"
      assert List.last(labels) == "2023-03-01 23:59:00"

      assert response["results"] == [
               %{"dimensions" => ["2023-03-01 12:00:00"], "metrics" => [1]}
             ]
    end

    test "trims hourly relative date range", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-08 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-08 06:05:00]),
        build(:pageview, timestamp: ~N[2021-01-08 08:59:00]),
        build(:pageview, timestamp: ~N[2021-01-08 23:59:00])
      ])

      response =
        do_query(
          conn,
          site,
          %{
            "date_range" => "day",
            "relative_date" => "2021-01-08",
            "metrics" => ["visitors"],
            "dimensions" => ["time:hour"],
            "include" => %{"time_labels" => true}
          },
          now: ~U[2021-01-08 08:05:00Z]
        )

      assert response["meta"]["time_labels"] == [
               "2021-01-08 00:00:00",
               "2021-01-08 01:00:00",
               "2021-01-08 02:00:00",
               "2021-01-08 03:00:00",
               "2021-01-08 04:00:00",
               "2021-01-08 05:00:00",
               "2021-01-08 06:00:00",
               "2021-01-08 07:00:00",
               "2021-01-08 08:00:00"
             ]

      assert response["results"] == [
               %{"dimensions" => ["2021-01-08 00:00:00"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-08 06:00:00"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-08 08:00:00"], "metrics" => [1]}
             ]
    end

    test "trims monthly relative date range", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-05 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-07 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00])
      ])

      response =
        do_query(
          conn,
          site,
          %{
            "date_range" => "month",
            "relative_date" => "2021-01-07",
            "metrics" => ["visitors"],
            "dimensions" => ["time:day"],
            "include" => %{"time_labels" => true}
          },
          now: ~U[2021-01-07 12:00:00Z]
        )

      assert response["meta"]["time_labels"] == [
               "2021-01-01",
               "2021-01-02",
               "2021-01-03",
               "2021-01-04",
               "2021-01-05",
               "2021-01-06",
               "2021-01-07"
             ]

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-05"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-07"], "metrics" => [1]}
             ]
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

      response =
        do_query(
          conn,
          site,
          %{
            "date_range" => "year",
            "relative_date" => "2021-02-07",
            "metrics" => ["visitors"],
            "dimensions" => ["time:month"],
            "include" => %{"time_labels" => true}
          },
          now: ~U[2021-02-07 12:00:00Z]
        )

      assert response["meta"]["time_labels"] == ["2021-01-01", "2021-02-01"]

      assert response["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [4]},
               %{"dimensions" => ["2021-02-01"], "metrics" => [1]}
             ]
    end
  end

  describe "comparisons" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "returns past month stats when period=30d and comparison=previous_period", %{
      conn: conn,
      site: site
    } do
      response =
        do_query(conn, site, %{
          "date_range" => "30d",
          "metrics" => ["visitors"],
          "dimensions" => ["time:day"],
          "include" => %{"compare" => "previous_period", "time_labels" => true}
        })

      labels = response["meta"]["time_labels"]

      comparison_labels =
        Enum.map(response["results"], fn r ->
          r["comparison"] && List.first(r["comparison"]["dimensions"])
        end)

      first = Date.utc_today() |> Date.shift(day: -30) |> Date.to_iso8601()
      last = Date.utc_today() |> Date.shift(day: -1) |> Date.to_iso8601()

      assert List.first(labels) == first
      assert List.last(labels) == last

      first = Date.utc_today() |> Date.shift(day: -60) |> Date.to_iso8601()
      last = Date.utc_today() |> Date.shift(day: -31) |> Date.to_iso8601()

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

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2020-01-01",
          "metrics" => ["visitors"],
          "dimensions" => ["time:day"],
          "include" => %{"compare" => "year_over_year"}
        })

      results = response["results"]

      assert Enum.at(results, 0)["metrics"] == [1]
      assert Enum.at(results, 0)["comparison"]["metrics"] == [2]

      assert Enum.at(results, 4)["metrics"] == [1]
      assert Enum.at(results, 4)["comparison"]["metrics"] == [2]

      assert Enum.at(results, 30)["metrics"] == [1]
      assert Enum.at(results, 30)["comparison"]["metrics"] == [1]
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

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2020-01-01",
          "metrics" => ["visitors"],
          "dimensions" => ["time:day"],
          "include" => %{
            "compare" => ["2022-01-01", "2022-06-01"],
            "time_labels" => true
          }
        })

      results = response["results"]
      labels = response["meta"]["time_labels"]

      assert length(results) == length(labels)
      assert List.last(results)["dimensions"] == nil
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

      response =
        do_query(conn, site, %{
          "date_range" => "year",
          "relative_date" => "2021-01-01",
          "metrics" => ["visitors"],
          "dimensions" => ["time:month"],
          "include" => %{"imports" => true, "compare" => "year_over_year"}
        })

      results = response["results"]
      plot = Enum.map(results, fn r -> List.first(r["metrics"]) end)
      comparison_plot = Enum.map(results, fn r -> List.first(r["comparison"]["metrics"]) end)

      assert 4 == Enum.sum(plot)
      assert 2 == Enum.sum(comparison_plot)
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

      response =
        do_query(conn, site, %{
          "date_range" => "year",
          "relative_date" => "2021-01-01",
          "metrics" => ["visitors"],
          "dimensions" => ["time:month"],
          "include" => %{"imports" => false, "compare" => "year_over_year"}
        })

      results = response["results"]
      plot = Enum.map(results, fn r -> List.first(r["metrics"]) end)
      comparison_plot = Enum.map(results, fn r -> List.first(r["comparison"]["metrics"]) end)

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

      response =
        do_query(conn, site, %{
          "date_range" => "7d",
          "relative_date" => "2021-01-15",
          "metrics" => ["conversion_rate"],
          "dimensions" => ["time:day"],
          "filters" => [["is", "event:goal", ["Signup"]]],
          "include" => %{"compare" => "previous_period"}
        })

      results = response["results"]
      this_week_plot = Enum.map(results, fn r -> List.first(r["metrics"]) end)
      last_week_plot = Enum.map(results, fn r -> List.first(r["comparison"]["metrics"]) end)

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

      response =
        do_query(
          conn,
          site,
          %{
            "date_range" => "day",
            "relative_date" => "2021-01-08",
            "metrics" => ["visitors"],
            "dimensions" => ["time:hour"],
            "include" => %{"compare" => "previous_period", "time_labels" => true}
          },
          now: ~U[2021-01-08 08:05:00Z]
        )

      results = response["results"]

      assert response["meta"]["time_labels"] == [
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
             ]

      assert Enum.map(results, fn r -> List.first(r["metrics"]) end) ==
               [1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]

      assert Enum.map(results, fn r -> List.first(r["comparison"]["metrics"]) end) ==
               List.duplicate(0, 24)
    end
  end

  describe "total_revenue plot" do
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

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-01-01",
          "metrics" => ["total_revenue"],
          "dimensions" => ["time:day"],
          "filters" => [["is", "event:goal", ["Payment"]]]
        })

      assert response["results"] == [
               %{
                 "dimensions" => ["2021-01-01"],
                 "metrics" => [
                   %{
                     "currency" => "USD",
                     "long" => "$13.29",
                     "short" => "$13.3",
                     "value" => 13.29
                   }
                 ]
               },
               %{
                 "dimensions" => ["2021-01-05"],
                 "metrics" => [
                   %{"currency" => "USD", "long" => "$19.90", "short" => "$19.9", "value" => 19.9}
                 ]
               },
               %{
                 "dimensions" => ["2021-01-31"],
                 "metrics" => [
                   %{
                     "currency" => "USD",
                     "long" => "$30.31",
                     "short" => "$30.3",
                     "value" => 30.31
                   }
                 ]
               }
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

      response =
        do_query(conn, site, %{
          "date_range" => "7d",
          "relative_date" => "2021-01-15",
          "metrics" => ["total_revenue"],
          "dimensions" => ["time:day"],
          "filters" => [["is", "event:goal", ["PaymentUSD"]]],
          "include" => %{"compare" => "previous_period"}
        })

      results = response["results"]

      assert Enum.map(results, fn r -> List.first(r["metrics"]) end) == [
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$10.31", "short" => "$10.3", "value" => 10.31},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$30.00", "short" => "$30.0", "value" => 30.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0}
             ]

      assert Enum.map(results, fn r -> List.first(r["comparison"]["metrics"]) end) == [
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

  describe "average_revenue plot" do
    @describetag :ee_only
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

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

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-01-01",
          "metrics" => ["average_revenue"],
          "dimensions" => ["time:day"],
          "filters" => [["is", "event:goal", ["Payment"]]]
        })

      assert response["results"] == [
               %{
                 "dimensions" => ["2021-01-01"],
                 "metrics" => [
                   %{
                     "currency" => "USD",
                     "long" => "$31.90",
                     "short" => "$31.9",
                     "value" => 31.895
                   }
                 ]
               },
               %{
                 "dimensions" => ["2021-01-05"],
                 "metrics" => [
                   %{"currency" => "USD", "long" => "$19.90", "short" => "$19.9", "value" => 19.9}
                 ]
               },
               %{
                 "dimensions" => ["2021-01-31"],
                 "metrics" => [
                   %{
                     "currency" => "USD",
                     "long" => "$15.16",
                     "short" => "$15.2",
                     "value" => 15.155
                   }
                 ]
               }
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

      response =
        do_query(conn, site, %{
          "date_range" => "7d",
          "relative_date" => "2021-01-15",
          "metrics" => ["average_revenue"],
          "dimensions" => ["time:day"],
          "filters" => [["is", "event:goal", ["PaymentUSD"]]],
          "include" => %{"compare" => "previous_period"}
        })

      results = response["results"]

      assert Enum.map(results, fn r -> List.first(r["metrics"]) end) == [
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$10.31", "short" => "$10.3", "value" => 10.31},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$15.00", "short" => "$15.0", "value" => 15.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0},
               %{"currency" => "USD", "long" => "$0.00", "short" => "$0.0", "value" => 0.0}
             ]

      assert Enum.map(results, fn r -> List.first(r["comparison"]["metrics"]) end) == [
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

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "metrics" => ["pageviews"],
          "dimensions" => ["time:day"],
          "include" => %{"time_labels" => true, "present_index" => true}
        })

      present_index = response["meta"]["present_index"]

      assert present_index >= 0
    end

    test "is null for a date range that does not include the current day", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview)
      ])

      response =
        do_query(conn, site, %{
          "date_range" => "month",
          "relative_date" => "2021-01-01",
          "metrics" => ["pageviews"],
          "dimensions" => ["time:day"],
          "include" => %{"time_labels" => true, "present_index" => true}
        })

      refute response["meta"]["present_index"]
    end

    for period <- ["7d", "28d", "30d", "91d"] do
      test "#{period} period does not include today", %{conn: conn, site: site} do
        today = "2021-01-01"
        yesterday = "2020-12-31"

        response =
          do_query(conn, site, %{
            "date_range" => unquote(period),
            "relative_date" => today,
            "metrics" => ["pageviews"],
            "dimensions" => ["time:day"],
            "include" => %{"time_labels" => true, "present_index" => true}
          })

        labels = response["meta"]["time_labels"]
        present_index = response["meta"]["present_index"]

        refute present_index
        assert List.last(labels) == yesterday
      end
    end
  end
end
