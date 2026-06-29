defmodule PlausibleWeb.Api.StatsController.DashboardCsvExportTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Repo

  @default_reports %{
    "visitors.csv" => %{
      dimensions: ["time:day"],
      metrics: [
        "visitors",
        "pageviews",
        "visits",
        "views_per_visit",
        "bounce_rate",
        "visit_duration"
      ]
    },
    "sources.csv" => %{
      dimensions: ["visit:source"],
      metrics: ["visitors", "bounce_rate", "visit_duration"]
    },
    "channels.csv" => %{
      dimensions: ["visit:channel"],
      metrics: ["visitors", "bounce_rate", "visit_duration"]
    },
    "referrers.csv" => %{
      dimensions: ["visit:referrer"],
      metrics: ["visitors", "bounce_rate", "visit_duration"]
    },
    "utm_mediums.csv" => %{
      dimensions: ["visit:utm_medium"],
      always_on_filters: [["is_not", "visit:utm_medium", [""]]],
      metrics: ["visitors", "bounce_rate", "visit_duration"]
    },
    "utm_sources.csv" => %{
      dimensions: ["visit:utm_source"],
      always_on_filters: [["is_not", "visit:utm_source", [""]]],
      metrics: ["visitors", "bounce_rate", "visit_duration"]
    },
    "utm_campaigns.csv" => %{
      dimensions: ["visit:utm_campaign"],
      always_on_filters: [["is_not", "visit:utm_campaign", [""]]],
      metrics: ["visitors", "bounce_rate", "visit_duration"]
    },
    "utm_contents.csv" => %{
      dimensions: ["visit:utm_content"],
      always_on_filters: [["is_not", "visit:utm_content", [""]]],
      metrics: ["visitors", "bounce_rate", "visit_duration"]
    },
    "utm_terms.csv" => %{
      dimensions: ["visit:utm_term"],
      always_on_filters: [["is_not", "visit:utm_term", [""]]],
      metrics: ["visitors", "bounce_rate", "visit_duration"]
    },
    "pages.csv" => %{
      dimensions: ["event:page"],
      metrics: ["visitors", "pageviews", "bounce_rate", "time_on_page", "scroll_depth"]
    },
    "entry_pages.csv" => %{
      dimensions: ["visit:entry_page"],
      always_on_filters: [["is_not", "visit:entry_page", [""]]],
      metrics: ["visitors", "visits", "bounce_rate", "visit_duration"]
    },
    "exit_pages.csv" => %{
      dimensions: ["visit:exit_page"],
      always_on_filters: [["is_not", "visit:exit_page", [""]]],
      metrics: ["visitors", "visits", "exit_rate"]
    },
    "browsers.csv" => %{
      dimensions: ["visit:browser"],
      metrics: ["visitors"]
    },
    "browser_versions.csv" => %{
      dimensions: ["visit:browser_version", "visit:browser"],
      metrics: ["visitors"]
    },
    "operating_systems.csv" => %{
      dimensions: ["visit:os"],
      metrics: ["visitors"]
    },
    "operating_system_versions.csv" => %{
      dimensions: ["visit:os_version", "visit:os"],
      metrics: ["visitors"]
    },
    "devices.csv" => %{
      dimensions: ["visit:device"],
      metrics: ["visitors"]
    },
    "countries.csv" => %{
      dimensions: ["visit:country_name"],
      always_on_filters: [["is_not", "visit:country", ["\0\0", "ZZ"]]],
      metrics: ["visitors"]
    },
    "regions.csv" => %{
      dimensions: ["visit:region_name"],
      always_on_filters: [["is_not", "visit:region", [""]]],
      metrics: ["visitors"]
    },
    "cities.csv" => %{
      dimensions: ["visit:city_name"],
      always_on_filters: [["is_not", "visit:city", [0]]],
      metrics: ["visitors"]
    },
    "custom_props.csv" => %{
      dimensions: ["event:props:*"],
      metrics: ["visitors", "events", "percentage"]
    },
    "conversions.csv" => %{
      dimensions: ["event:goal"],
      metrics: ["visitors", "events"]
    }
  }

  @page_filtered_reports put_in(@default_reports, ["visitors.csv", :metrics], [
                           "visitors",
                           "pageviews",
                           "visits",
                           "bounce_rate",
                           "time_on_page",
                           "scroll_depth"
                         ])
                         |> put_in(
                           ["exit_pages.csv", :metrics],
                           get_in(@default_reports, ["exit_pages.csv", :metrics]) -- ["exit_rate"]
                         )
  @prop_filtered_reports put_in(
                           @default_reports,
                           ["exit_pages.csv", :metrics],
                           get_in(@default_reports, ["exit_pages.csv", :metrics]) -- ["exit_rate"]
                         )

  @goal_filtered_reports Map.new(@default_reports, fn
                           {"visitors.csv" = filename, params} ->
                             {filename,
                              %{params | metrics: ["visitors", "events", "group_conversion_rate"]}}

                           {"custom_props.csv" = filename, params} ->
                             {filename,
                              %{params | metrics: ["visitors", "events", "conversion_rate"]}}

                           {"conversions.csv" = filename, params} ->
                             {filename, params}

                           {filename, params} ->
                             {filename,
                              %{params | metrics: ["visitors", "group_conversion_rate"]}}
                         end)

  @base_params %{
    date_range: "30d",
    relative_date: nil,
    filters: [],
    include: %{imports: false},
    reports: @default_reports
  }

  describe "POST /api/stats/:domain/export" do
    setup [:create_user, :create_site, :log_in]

    test "exports all the necessary CSV files", %{conn: conn, site: site} do
      conn = do_export(conn, site, @base_params)

      assert {"content-type", "application/zip; charset=utf-8"} =
               List.keyfind(conn.resp_headers, "content-type", 0)

      {:ok, zip} = :zip.unzip(response(conn, 200), [:memory])

      zip = Enum.map(zip, fn {filename, _} -> filename end)

      assert ~c"visitors.csv" in zip
      assert ~c"browsers.csv" in zip
      assert ~c"browser_versions.csv" in zip
      assert ~c"cities.csv" in zip
      assert ~c"conversions.csv" in zip
      assert ~c"countries.csv" in zip
      assert ~c"devices.csv" in zip
      assert ~c"entry_pages.csv" in zip
      assert ~c"exit_pages.csv" in zip
      assert ~c"operating_systems.csv" in zip
      assert ~c"operating_system_versions.csv" in zip
      assert ~c"pages.csv" in zip
      assert ~c"regions.csv" in zip
      assert ~c"sources.csv" in zip
      assert ~c"channels.csv" in zip
      assert ~c"utm_campaigns.csv" in zip
      assert ~c"utm_contents.csv" in zip
      assert ~c"utm_mediums.csv" in zip
      assert ~c"utm_sources.csv" in zip
      assert ~c"utm_terms.csv" in zip
    end

    test "limits pages.csv and exit_pages.csv to 100 rows", %{conn: conn, site: site} do
      events = for i <- 1..101, do: build(:pageview, pathname: "/page-#{i}")
      populate_stats(site, events)

      zip_content =
        conn
        |> do_export(site, %{@base_params | date_range: "day"})
        |> response(200)

      pages = unzip_and_parse_csv(zip_content, ~c"pages.csv")
      # header + 100 data rows + trailing empty row
      assert length(pages) == 102

      exit_pages = unzip_and_parse_csv(zip_content, ~c"exit_pages.csv")
      assert length(exit_pages) == 102
    end

    test "limits custom_props.csv to 25 prop keys", %{conn: conn, site: site} do
      keys = for i <- 1..26, do: "key_#{i}"
      {:ok, site} = Plausible.Props.allow(site, keys)

      populate_stats(site, [
        build(:pageview,
          "meta.key": keys,
          "meta.value": List.duplicate("v", 26)
        )
      ])

      custom_props =
        conn
        |> do_export(site, %{@base_params | date_range: "day"})
        |> response(200)
        |> unzip_and_parse_csv(~c"custom_props.csv")

      prop_keys =
        custom_props
        |> Enum.drop(1)
        |> Enum.reject(&(&1 == [""]))
        |> Enum.map(&hd/1)
        |> Enum.uniq()

      assert length(prop_keys) == 25
    end

    test "limits other breakdown reports to 300 rows", %{conn: conn, site: site} do
      events = for i <- 1..301, do: build(:pageview, referrer_source: "Source #{i}")
      populate_stats(site, events)

      sources =
        conn
        |> do_export(site, %{@base_params | date_range: "day"})
        |> response(200)
        |> unzip_and_parse_csv(~c"sources.csv")

      # header + 300 data rows + trailing empty row
      assert length(sources) == 302
    end

    test "exports scroll depth metric in pages.csv", %{conn: conn, site: site} do
      t0 = ~N[2020-01-01 00:00:00]
      [t1, t2, t3] = for i <- 1..3, do: NaiveDateTime.add(t0, i, :minute)

      populate_stats(site, [
        build(:pageview, user_id: 12, pathname: "/blog", timestamp: t0),
        build(:engagement,
          user_id: 12,
          pathname: "/blog",
          timestamp: t1,
          scroll_depth: 20,
          engagement_time: 60_000
        ),
        build(:pageview, user_id: 12, pathname: "/another", timestamp: t1),
        build(:engagement,
          user_id: 12,
          pathname: "/another",
          timestamp: t2,
          scroll_depth: 24,
          engagement_time: 60_000
        ),
        build(:pageview, user_id: 34, pathname: "/blog", timestamp: t0),
        build(:engagement,
          user_id: 34,
          pathname: "/blog",
          timestamp: t1,
          scroll_depth: 17,
          engagement_time: 60_000
        ),
        build(:pageview, user_id: 34, pathname: "/another", timestamp: t1),
        build(:engagement,
          user_id: 34,
          pathname: "/another",
          timestamp: t2,
          scroll_depth: 26,
          engagement_time: 60_000
        ),
        build(:pageview, user_id: 34, pathname: "/blog", timestamp: t2),
        build(:engagement,
          user_id: 34,
          pathname: "/blog",
          timestamp: t3,
          scroll_depth: 60,
          engagement_time: 60_000
        ),
        build(:pageview, user_id: 56, pathname: "/blog", timestamp: t0),
        build(:engagement,
          user_id: 56,
          pathname: "/blog",
          timestamp: t1,
          scroll_depth: 100,
          engagement_time: 60_000
        )
      ])

      pages =
        conn
        |> do_export(site, %{@base_params | date_range: "day", relative_date: "2020-01-01"})
        |> response(200)
        |> unzip_and_parse_csv(~c"pages.csv")

      assert pages == [
               ["name", "visitors", "pageviews", "bounce_rate", "time_on_page", "scroll_depth"],
               ["/blog", "3", "4", "33", "80", "60"],
               ["/another", "2", "2", "0", "60", "25"],
               [""]
             ]
    end

    test "exports only internally used props in custom_props.csv for a growth plan", %{
      conn: conn,
      site: site
    } do
      {:ok, site} = Plausible.Props.allow(site, ["author"])

      [owner | _] = Repo.preload(site, :owners).owners
      subscribe_to_growth_plan(owner)

      populate_stats(site, [
        build(:pageview, "meta.key": ["author"], "meta.value": ["a"]),
        build(:event, name: "File Download", "meta.key": ["url"], "meta.value": ["b"])
      ])

      result =
        conn
        |> do_export(site, %{@base_params | date_range: "day"})
        |> response(200)
        |> unzip_and_parse_csv(~c"custom_props.csv")

      assert result == [
               ["property", "value", "visitors", "events", "percentage"],
               ["url", "(none)", "1", "1", "50.0"],
               ["url", "b", "1", "1", "50.0"],
               [""]
             ]
    end

    test "does not include custom_props.csv for a growth plan if no internal props used", %{
      conn: conn,
      site: site
    } do
      {:ok, site} = Plausible.Props.allow(site, ["author"])

      [owner | _] = Repo.preload(site, :owners).owners
      subscribe_to_growth_plan(owner)

      populate_stats(site, [
        build(:pageview, "meta.key": ["author"], "meta.value": ["a"])
      ])

      {:ok, zip} =
        conn
        |> do_export(site, %{@base_params | date_range: "day"})
        |> response(200)
        |> :zip.unzip([:memory])

      files = Map.new(zip)

      refute Map.has_key?(files, ~c"custom_props.csv")
    end

    test "exports data in zipped csvs", %{conn: conn, site: site} do
      populate_exported_stats(site)

      conn =
        do_export(conn, site, %{@base_params | date_range: ["2021-09-20", "2021-10-20"]})

      assert_zip(conn, "30d")
    end

    test "exports allowed event props for a trial account", %{conn: conn, site: site} do
      {:ok, site} = Plausible.Props.allow(site, ["author", "logged_in"])

      populate_stats(site, [
        build(:pageview, "meta.key": ["author"], "meta.value": ["uku"]),
        build(:pageview, "meta.key": ["author"], "meta.value": ["uku"]),
        build(:event, "meta.key": ["author"], "meta.value": ["marko"], name: "Newsletter Signup"),
        build(:pageview, user_id: 999, "meta.key": ["logged_in"], "meta.value": ["true"]),
        build(:pageview, user_id: 999, "meta.key": ["logged_in"], "meta.value": ["true"]),
        build(:pageview, "meta.key": ["disallowed"], "meta.value": ["whatever"]),
        build(:pageview)
      ])

      result =
        conn
        |> do_export(site, %{@base_params | date_range: "day"})
        |> response(200)
        |> unzip_and_parse_csv(~c"custom_props.csv")

      assert result == [
               ["property", "value", "visitors", "events", "percentage"],
               ["author", "(none)", "3", "4", "50.0"],
               ["author", "uku", "2", "2", "33.33"],
               ["author", "marko", "1", "1", "16.67"],
               ["logged_in", "(none)", "5", "5", "83.33"],
               ["logged_in", "true", "1", "2", "16.67"],
               [""]
             ]
    end

    test "exports data grouped by interval", %{conn: conn, site: site} do
      populate_exported_stats(site)

      params =
        @base_params
        |> Map.put(:date_range, ["2021-09-20", "2021-10-20"])
        |> put_in([:reports, "visitors.csv", :dimensions], ["time:week"])

      visitors =
        conn
        |> do_export(site, params)
        |> response(200)
        |> unzip_and_parse_csv(~c"visitors.csv")

      assert visitors == [
               [
                 "date",
                 "visitors",
                 "pageviews",
                 "visits",
                 "views_per_visit",
                 "bounce_rate",
                 "visit_duration"
               ],
               ["2021-09-20", "1", "1", "1", "1.0", "100", "0"],
               ["2021-09-27", "0", "0", "0", "0.0", "0.0", ""],
               ["2021-10-04", "0", "0", "0", "0.0", "0.0", ""],
               ["2021-10-11", "0", "0", "0", "0.0", "0.0", ""],
               ["2021-10-18", "3", "4", "3", "1.33", "33", "40"],
               [""]
             ]
    end

    test "exports operating system versions", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, operating_system: "Mac", operating_system_version: "14"),
        build(:pageview, operating_system: "Mac", operating_system_version: "14"),
        build(:pageview, operating_system: "Mac", operating_system_version: "14"),
        build(:pageview, operating_system: "Ubuntu", operating_system_version: "20.04"),
        build(:pageview, operating_system: "Ubuntu", operating_system_version: "20.04"),
        build(:pageview, operating_system: "Mac", operating_system_version: "13")
      ])

      os_versions =
        conn
        |> do_export(site, %{@base_params | date_range: "day"})
        |> response(200)
        |> unzip_and_parse_csv(~c"operating_system_versions.csv")

      assert os_versions == [
               ["name", "version", "visitors"],
               ["Mac", "14", "3"],
               ["Ubuntu", "20.04", "2"],
               ["Mac", "13", "1"],
               [""]
             ]
    end

    test "exports imported data when requested", %{conn: conn, site: site} do
      site_import = insert(:site_import, site: site)

      insert(:goal, site: site, event_name: "Outbound Link: Click")

      populate_stats(site, site_import.id, [
        build(:imported_visitors, visitors: 9),
        build(:imported_browsers, browser: "Chrome", pageviews: 1),
        build(:imported_devices, device: "Desktop", pageviews: 1),
        build(:imported_entry_pages, entry_page: "/test", pageviews: 1),
        build(:imported_exit_pages, exit_page: "/test", pageviews: 1),
        build(:imported_locations, country: "PL", region: "PL-22", city: 3_099_434, pageviews: 1),
        build(:imported_operating_systems, operating_system: "Mac", pageviews: 1),
        build(:imported_pages, page: "/test", pageviews: 1),
        build(:imported_sources,
          source: "Google",
          channel: "Paid Search",
          utm_medium: "search",
          utm_campaign: "ads",
          utm_source: "google",
          utm_content: "content",
          utm_term: "term",
          pageviews: 1
        ),
        build(:imported_custom_events,
          name: "Outbound Link: Click",
          link_url: "https://example.com",
          visitors: 5,
          events: 10
        )
      ])

      tomorrow = Date.utc_today() |> Date.add(1) |> Date.to_iso8601()

      params = %{@base_params | relative_date: tomorrow, include: %{imports: true}}

      assert response = do_export(conn, site, params) |> response(200)
      {:ok, zip} = :zip.unzip(response, [:memory])

      filenames = zip |> Enum.map(fn {filename, _} -> to_string(filename) end)

      # NOTE: currently, custom_props.csv is not populated from imported data
      expected_filenames = [
        "visitors.csv",
        "sources.csv",
        "channels.csv",
        "utm_mediums.csv",
        "utm_sources.csv",
        "utm_campaigns.csv",
        "utm_contents.csv",
        "utm_terms.csv",
        "pages.csv",
        "entry_pages.csv",
        "exit_pages.csv",
        "countries.csv",
        "regions.csv",
        "cities.csv",
        "browsers.csv",
        "browser_versions.csv",
        "operating_systems.csv",
        "operating_system_versions.csv",
        "devices.csv",
        "conversions.csv",
        "referrers.csv"
      ]

      Enum.each(expected_filenames, fn expected -> assert expected in filenames end)

      Enum.each(zip, fn
        {~c"visitors.csv", data} ->
          csv = parse_csv(data)

          assert List.first(csv) == [
                   "date",
                   "visitors",
                   "pageviews",
                   "visits",
                   "views_per_visit",
                   "bounce_rate",
                   "visit_duration"
                 ]

          assert Enum.at(csv, -2) ==
                   [Date.to_iso8601(Date.utc_today()), "9", "1", "1", "1.0", "0.0", "10.0"]

        {~c"sources.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "visitors", "bounce_rate", "visit_duration"],
                   ["Google", "1", "0.0", "10.0"],
                   [""]
                 ]

        {~c"channels.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "visitors", "bounce_rate", "visit_duration"],
                   ["Paid Search", "1", "0.0", "10.0"],
                   [""]
                 ]

        {~c"utm_mediums.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "visitors", "bounce_rate", "visit_duration"],
                   ["search", "1", "0.0", "10.0"],
                   [""]
                 ]

        {~c"utm_sources.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "visitors", "bounce_rate", "visit_duration"],
                   ["google", "1", "0.0", "10.0"],
                   [""]
                 ]

        {~c"utm_campaigns.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "visitors", "bounce_rate", "visit_duration"],
                   ["ads", "1", "0.0", "10.0"],
                   [""]
                 ]

        {~c"utm_contents.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "visitors", "bounce_rate", "visit_duration"],
                   ["content", "1", "0.0", "10.0"],
                   [""]
                 ]

        {~c"utm_terms.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "visitors", "bounce_rate", "visit_duration"],
                   ["term", "1", "0.0", "10.0"],
                   [""]
                 ]

        {~c"pages.csv", data} ->
          assert parse_csv(data) == [
                   [
                     "name",
                     "visitors",
                     "pageviews",
                     "bounce_rate",
                     "time_on_page",
                     "scroll_depth"
                   ],
                   ["/test", "1", "1", "0.0", "10", ""],
                   [""]
                 ]

        {~c"entry_pages.csv", data} ->
          assert parse_csv(data) == [
                   [
                     "name",
                     "unique_entrances",
                     "total_entrances",
                     "bounce_rate",
                     "visit_duration"
                   ],
                   ["/test", "1", "1", "0.0", "10.0"],
                   [""]
                 ]

        {~c"exit_pages.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "unique_exits", "total_exits", "exit_rate"],
                   ["/test", "1", "1", "100.0"],
                   [""]
                 ]

        {~c"countries.csv", data} ->
          assert parse_csv(data) == [["name", "visitors"], ["Poland", "1"], [""]]

        {~c"regions.csv", data} ->
          assert parse_csv(data) == [["name", "visitors"], ["Pomerania", "1"], [""]]

        {~c"cities.csv", data} ->
          assert parse_csv(data) == [["name", "visitors"], ["Gdańsk", "1"], [""]]

        {~c"browsers.csv", data} ->
          assert parse_csv(data) == [["name", "visitors"], ["Chrome", "1"], [""]]

        {~c"browser_versions.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "version", "visitors"],
                   ["Chrome", "(not set)", "1"],
                   [""]
                 ]

        {~c"operating_systems.csv", data} ->
          assert parse_csv(data) == [["name", "visitors"], ["Mac", "1"], [""]]

        {~c"operating_system_versions.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "version", "visitors"],
                   ["Mac", "(not set)", "1"],
                   [""]
                 ]

        {~c"devices.csv", data} ->
          assert parse_csv(data) == [["name", "visitors"], ["Desktop", "1"], [""]]

        {~c"conversions.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "unique_conversions", "total_conversions"],
                   ["Outbound Link: Click", "5", "10"],
                   [""]
                 ]

        {~c"referrers.csv", data} ->
          assert parse_csv(data) == [
                   ["name", "visitors", "bounce_rate", "visit_duration"],
                   ["Direct / None", "1", "0.0", "10.0"],
                   [""]
                 ]

        {~c"custom_props.csv", _data} ->
          :ok
      end)
    end
  end

  defp parse_csv(file_content) when is_binary(file_content) do
    file_content
    |> String.split("\r\n")
    |> Enum.map(&String.split(&1, ","))
  end

  describe "POST /api/stats/:domain/export - via shared link" do
    setup [:create_user, :create_site]

    test "exports data in zipped csvs", %{conn: conn, site: site} do
      link = insert(:shared_link, site: site)

      populate_exported_stats(site)

      params =
        %{@base_params | date_range: ["2021-09-20", "2021-10-20"], include: %{imports: false}}
        |> Map.put(:auth, link.slug)

      conn = do_export(conn, site, params)

      assert_zip(conn, "30d")
    end
  end

  describe "POST /api/stats/:domain/export - for past 6 months" do
    setup [:create_user, :create_site, :log_in]

    test "exports 6 months of data in zipped csvs", %{conn: conn, site: site} do
      populate_exported_stats(site)

      conn =
        do_export(conn, site, %{
          @base_params
          | date_range: "6mo",
            relative_date: "2021-11-20",
            reports: put_in(@default_reports, ["visitors.csv", :dimensions], ["time:month"])
        })

      assert_zip(conn, "6m")
    end
  end

  describe "POST /api/stats/:domain/export - with path filter" do
    setup [:create_user, :create_site, :log_in]

    test "exports filtered data in zipped csvs", %{conn: conn, site: site} do
      populate_exported_stats(site)

      conn =
        do_export(conn, site, %{
          @base_params
          | date_range: ["2021-09-20", "2021-10-20"],
            filters: [["is", "event:page", ["/some-other-page"]]],
            reports: @page_filtered_reports
        })

      assert_zip(conn, "30d-filter-path")
    end

    test "exports scroll depth in visitors.csv", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 12, pathname: "/blog", timestamp: ~N[2020-01-05 00:00:00]),
        build(:engagement,
          user_id: 12,
          pathname: "/blog",
          timestamp: ~N[2020-01-05 00:01:00],
          scroll_depth: 40
        ),
        build(:pageview, user_id: 12, pathname: "/blog", timestamp: ~N[2020-01-05 10:00:00]),
        build(:engagement,
          user_id: 12,
          pathname: "/blog",
          timestamp: ~N[2020-01-05 10:01:00],
          scroll_depth: 17
        ),
        build(:pageview, user_id: 34, pathname: "/blog", timestamp: ~N[2020-01-07 00:00:00]),
        build(:engagement,
          user_id: 34,
          pathname: "/blog",
          timestamp: ~N[2020-01-07 00:01:00],
          scroll_depth: 90
        )
      ])

      pages =
        conn
        |> do_export(site, %{
          @base_params
          | date_range: "7d",
            relative_date: "2020-01-08",
            filters: [["is", "event:page", ["/blog"]]],
            reports: @page_filtered_reports
        })
        |> response(200)
        |> unzip_and_parse_csv(~c"visitors.csv")

      assert pages == [
               [
                 "date",
                 "visitors",
                 "pageviews",
                 "visits",
                 "bounce_rate",
                 "time_on_page",
                 "scroll_depth"
               ],
               ["2020-01-01", "0", "0", "0", "0.0", "", ""],
               ["2020-01-02", "0", "0", "0", "0.0", "", ""],
               ["2020-01-03", "0", "0", "0", "0.0", "", ""],
               ["2020-01-04", "0", "0", "0", "0.0", "", ""],
               ["2020-01-05", "1", "2", "2", "100", "0", "28"],
               ["2020-01-06", "0", "0", "0", "0.0", "", ""],
               ["2020-01-07", "1", "1", "1", "100", "0", "90"],
               [""]
             ]
    end
  end

  describe "POST /api/stats/:domain/export - with a custom prop filter" do
    setup [:create_user, :create_site, :log_in]

    test "custom-props.csv only returns the prop and its value in filter", %{
      conn: conn,
      site: site
    } do
      {:ok, site} = Plausible.Props.allow(site, ["author", "logged_in"])

      populate_stats(site, [
        build(:pageview, "meta.key": ["author"], "meta.value": ["uku"]),
        build(:pageview, "meta.key": ["author"], "meta.value": ["marko"]),
        build(:pageview, "meta.key": ["logged_in"], "meta.value": ["true"])
      ])

      result =
        conn
        |> do_export(site, %{
          @base_params
          | date_range: "day",
            filters: [["is", "event:props:author", ["marko"]]],
            reports: @prop_filtered_reports
        })
        |> response(200)
        |> unzip_and_parse_csv(~c"custom_props.csv")

      assert result == [
               ["property", "value", "visitors", "events", "percentage"],
               ["author", "marko", "1", "1", "100.0"],
               [""]
             ]
    end
  end

  defp unzip_and_parse_csv(archive, filename) do
    {:ok, zip} = :zip.unzip(archive, [:memory])
    {_filename, data} = Enum.find(zip, &(elem(&1, 0) == filename))
    parse_csv(data)
  end

  defp assert_zip(conn, folder) do
    assert conn.status == 200

    assert {"content-type", "application/zip; charset=utf-8"} =
             List.keyfind(conn.resp_headers, "content-type", 0)

    {:ok, zip} = :zip.unzip(response(conn, 200), [:memory])

    folder = Path.expand(folder, "test/plausible_web/controllers/CSVs")

    Enum.map(zip, &assert_csv_by_fixture(&1, folder))
  end

  defp assert_csv_by_fixture({file, downloaded}, folder) do
    file = Path.expand(file, folder)

    {:ok, content} = File.read(file)
    msg = "CSV file comparison failed (#{file})"
    assert downloaded == content, message: msg, left: downloaded, right: content
  end

  defp do_export(conn, site, params) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post("/api/stats/#{site.domain}/export", Jason.encode!(params))
  end

  defp populate_exported_stats(site) do
    populate_stats(site, [
      build(:pageview,
        user_id: 123,
        pathname: "/",
        timestamp:
          NaiveDateTime.shift(~N[2021-10-20 12:00:00], minute: -1)
          |> NaiveDateTime.truncate(:second),
        country_code: "EE",
        subdivision1_code: "EE-37",
        city_geoname_id: 588_409,
        referrer_source: "Google"
      ),
      build(:engagement,
        user_id: 123,
        pathname: "/",
        timestamp: ~N[2021-10-20 12:00:00] |> NaiveDateTime.truncate(:second),
        engagement_time: 30_000,
        scroll_depth: 30,
        country_code: "EE",
        subdivision1_code: "EE-37",
        city_geoname_id: 588_409,
        referrer_source: "Google"
      ),
      build(:pageview,
        user_id: 123,
        pathname: "/some-other-page",
        timestamp:
          NaiveDateTime.shift(~N[2021-10-20 12:00:00], minute: -2)
          |> NaiveDateTime.truncate(:second),
        country_code: "EE",
        subdivision1_code: "EE-37",
        city_geoname_id: 588_409,
        referrer_source: "Google"
      ),
      build(:engagement,
        user_id: 123,
        pathname: "/some-other-page",
        timestamp:
          NaiveDateTime.shift(~N[2021-10-20 12:00:00], minute: -1)
          |> NaiveDateTime.truncate(:second),
        engagement_time: 60_000,
        scroll_depth: 30,
        country_code: "EE",
        subdivision1_code: "EE-37",
        city_geoname_id: 588_409,
        referrer_source: "Google"
      ),
      build(:pageview,
        user_id: 100,
        pathname: "/",
        timestamp:
          NaiveDateTime.shift(~N[2021-10-20 12:00:00], day: -1) |> NaiveDateTime.truncate(:second),
        utm_medium: "search",
        utm_campaign: "ads",
        utm_source: "google",
        utm_content: "content",
        utm_term: "term",
        browser: "Firefox",
        browser_version: "120",
        operating_system: "Mac",
        operating_system_version: "14"
      ),
      build(:engagement,
        user_id: 100,
        pathname: "/",
        timestamp:
          NaiveDateTime.shift(~N[2021-10-20 12:00:00], day: -1, minute: 1)
          |> NaiveDateTime.truncate(:second),
        engagement_time: 30_000,
        scroll_depth: 30,
        utm_medium: "search",
        utm_campaign: "ads",
        utm_source: "google",
        utm_content: "content",
        utm_term: "term",
        browser: "Firefox",
        browser_version: "120",
        operating_system: "Mac",
        operating_system_version: "14"
      ),
      build(:pageview,
        user_id: 200,
        timestamp:
          NaiveDateTime.shift(~N[2021-10-20 12:00:00], month: -1)
          |> NaiveDateTime.truncate(:second),
        country_code: "EE",
        browser: "Firefox",
        browser_version: "120",
        operating_system: "Mac",
        operating_system_version: "14"
      ),
      build(:engagement,
        user_id: 200,
        timestamp:
          NaiveDateTime.shift(~N[2021-10-20 12:00:00], month: -1, minute: 1)
          |> NaiveDateTime.truncate(:second),
        engagement_time: 30_000,
        scroll_depth: 20,
        country_code: "EE",
        browser: "Firefox",
        browser_version: "120",
        operating_system: "Mac",
        operating_system_version: "14"
      ),
      build(:pageview,
        user_id: 300,
        timestamp:
          NaiveDateTime.shift(~N[2021-10-20 12:00:00], month: -5)
          |> NaiveDateTime.truncate(:second),
        utm_campaign: "ads",
        country_code: "EE",
        referrer_source: "Google",
        click_id_param: "gclid",
        browser: "FirefoxNoVersion",
        operating_system: "MacNoVersion"
      ),
      build(:engagement,
        user_id: 300,
        timestamp:
          NaiveDateTime.shift(~N[2021-10-20 12:00:00], month: -5, minute: 1)
          |> NaiveDateTime.truncate(:second),
        engagement_time: 30_000,
        scroll_depth: 20,
        utm_campaign: "ads",
        country_code: "EE",
        referrer_source: "Google",
        click_id_param: "gclid",
        browser: "FirefoxNoVersion",
        operating_system: "MacNoVersion"
      ),
      build(:pageview,
        user_id: 456,
        timestamp:
          NaiveDateTime.shift(~N[2021-10-20 12:00:00], day: -1, minute: -1)
          |> NaiveDateTime.truncate(:second),
        pathname: "/signup",
        "meta.key": ["variant"],
        "meta.value": ["A"]
      ),
      build(:engagement,
        user_id: 456,
        timestamp:
          NaiveDateTime.shift(~N[2021-10-20 12:00:00], day: -1) |> NaiveDateTime.truncate(:second),
        pathname: "/signup",
        engagement_time: 60_000,
        scroll_depth: 20,
        "meta.key": ["variant"],
        "meta.value": ["A"]
      ),
      build(:event,
        user_id: 456,
        timestamp:
          NaiveDateTime.shift(~N[2021-10-20 12:00:00], day: -1) |> NaiveDateTime.truncate(:second),
        name: "Signup",
        "meta.key": ["variant"],
        "meta.value": ["A"]
      )
    ])

    insert(:goal, %{site: site, event_name: "Signup"})
  end

  describe "POST /api/stats/:domain/export - with goal filter" do
    setup [:create_user, :create_site, :log_in]

    test "exports goal-filtered data in zipped csvs", %{conn: conn, site: site} do
      populate_exported_stats(site)

      conn =
        do_export(conn, site, %{
          @base_params
          | date_range: ["2021-09-20", "2021-10-20"],
            filters: [["is", "event:goal", ["Signup"]]],
            reports: @goal_filtered_reports
        })

      assert_zip(conn, "30d-filter-goal")
    end

    test "custom-props.csv only returns the prop names for the goal in filter", %{
      conn: conn,
      site: site
    } do
      {:ok, site} = Plausible.Props.allow(site, ["author", "logged_in"])

      populate_stats(site, [
        build(:event, name: "Newsletter Signup", "meta.key": ["author"], "meta.value": ["uku"]),
        build(:event, name: "Newsletter Signup", "meta.key": ["author"], "meta.value": ["marko"]),
        build(:event, name: "Newsletter Signup", "meta.key": ["author"], "meta.value": ["marko"]),
        build(:pageview, "meta.key": ["logged_in"], "meta.value": ["true"])
      ])

      insert(:goal, site: site, event_name: "Newsletter Signup")

      result =
        conn
        |> do_export(site, %{
          @base_params
          | date_range: "day",
            filters: [["is", "event:goal", ["Newsletter Signup"]]],
            reports: @goal_filtered_reports
        })
        |> response(200)
        |> unzip_and_parse_csv(~c"custom_props.csv")

      assert result == [
               ["property", "value", "visitors", "events", "conversion_rate"],
               ["author", "marko", "2", "2", "50.0"],
               ["author", "uku", "1", "1", "25.0"],
               [""]
             ]
    end

    test "exports conversions and conversion rate for operating system versions", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, operating_system: "Mac", operating_system_version: "14"),
        build(:event, name: "Signup", operating_system: "Mac", operating_system_version: "14"),
        build(:event, name: "Signup", operating_system: "Mac", operating_system_version: "14"),
        build(:event, name: "Signup", operating_system: "Mac", operating_system_version: "14"),
        build(:event,
          name: "Signup",
          operating_system: "Ubuntu",
          operating_system_version: "20.04"
        ),
        build(:event,
          name: "Signup",
          operating_system: "Ubuntu",
          operating_system_version: "20.04"
        ),
        build(:event,
          name: "Signup",
          operating_system: "Lubuntu",
          operating_system_version: "20.04"
        )
      ])

      insert(:goal, site: site, event_name: "Signup")

      os_versions =
        conn
        |> do_export(site, %{
          @base_params
          | date_range: "day",
            filters: [["is", "event:goal", ["Signup"]]],
            reports: @goal_filtered_reports
        })
        |> response(200)
        |> unzip_and_parse_csv(~c"operating_system_versions.csv")

      assert os_versions == [
               ["name", "version", "conversions", "conversion_rate"],
               ["Mac", "14", "3", "75.0"],
               ["Ubuntu", "20.04", "2", "100.0"],
               ["Lubuntu", "20.04", "1", "100.0"],
               [""]
             ]
    end
  end
end
