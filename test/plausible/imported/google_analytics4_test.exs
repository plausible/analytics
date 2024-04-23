defmodule Plausible.Imported.GoogleAnalytics4Test do
  use PlausibleWeb.ConnCase, async: true
  use Oban.Testing, repo: Plausible.Repo

  import Mox
  import Ecto.Query, only: [from: 2]

  alias Plausible.ClickhouseRepo
  alias Plausible.Repo
  alias Plausible.Imported.GoogleAnalytics4

  @refresh_token_body Jason.decode!(File.read!("fixture/ga_refresh_token.json"))

  @full_report_mock [
                      "fixture/ga4_report_imported_visitors.json",
                      "fixture/ga4_report_imported_sources.json",
                      "fixture/ga4_report_imported_pages.json",
                      "fixture/ga4_report_imported_entry_pages.json",
                      "fixture/ga4_report_imported_custom_events.json",
                      "fixture/ga4_report_imported_locations.json",
                      "fixture/ga4_report_imported_devices.json",
                      "fixture/ga4_report_imported_browsers.json",
                      "fixture/ga4_report_imported_operating_systems.json"
                    ]
                    |> Enum.map(&File.read!/1)
                    |> Enum.map(&Jason.decode!/1)

  setup :verify_on_exit!

  describe "parse_args/1 and import_data/2" do
    setup [:create_user, :create_new_site]

    test "imports data returned from GA4 Data API", %{conn: conn, user: user, site: site} do
      past = DateTime.add(DateTime.utc_now(), -3600, :second)

      {:ok, job} =
        Plausible.Imported.GoogleAnalytics4.new_import(
          site,
          user,
          label: "properties/123456",
          property: "properties/123456",
          start_date: ~D[2024-01-01],
          end_date: ~D[2024-01-31],
          access_token: "redacted_access_token",
          refresh_token: "redacted_refresh_token",
          token_expires_at: DateTime.to_iso8601(past)
        )

      site_import = Plausible.Imported.get_import(site, job.args.import_id)

      assert site_import.label == "properties/123456"

      opts = job |> Repo.reload!() |> Map.get(:args) |> GoogleAnalytics4.parse_args()

      opts = Keyword.put(opts, :flush_interval_ms, 10)

      expect(Plausible.HTTPClient.Mock, :post, fn "https://www.googleapis.com/oauth2/v4/token",
                                                  headers,
                                                  body ->
        assert [{"content-type", "application/x-www-form-urlencoded"}] == headers

        assert %{
                 grant_type: :refresh_token,
                 redirect_uri: "http://localhost:8000/auth/google/callback",
                 refresh_token: "redacted_refresh_token"
               } = body

        {:ok, %Finch.Response{status: 200, body: @refresh_token_body}}
      end)

      for report <- @full_report_mock do
        expect(Plausible.HTTPClient.Mock, :post, fn _url, headers, _body, _opts ->
          assert [{"Authorization", "Bearer 1/fFAGRNJru1FTz70BzhT3Zg"}] == headers
          {:ok, %Finch.Response{status: 200, body: report}}
        end)
      end

      Enum.each(Plausible.Imported.tables(), fn table ->
        query = from(imported in table, where: imported.site_id == ^site.id)
        assert await_clickhouse_count(query, 0)
      end)

      assert :ok = GoogleAnalytics4.import_data(site_import, opts)

      Enum.each(Plausible.Imported.tables(), fn table ->
        count =
          case table do
            "imported_sources" -> 210
            "imported_visitors" -> 31
            "imported_pages" -> 3340
            "imported_entry_pages" -> 2934
            "imported_exit_pages" -> 0
            "imported_custom_events" -> 56
            "imported_locations" -> 2291
            "imported_devices" -> 93
            "imported_browsers" -> 233
            "imported_operating_systems" -> 1068
          end

        query = from(imported in table, where: imported.site_id == ^site.id)
        assert await_clickhouse_count(query, count)
      end)

      # NOTE: Consider using GoogleAnalytics.run_import instead of import_data
      # to avoid having to set SiteImport to completed manually
      site_import
      |> Plausible.Imported.SiteImport.complete_changeset()
      |> Repo.update!()

      # Assert the actual data via Stats API requests
      common_params = %{
        "site_id" => site.domain,
        "period" => "custom",
        "date" => "2024-01-01,2024-01-31",
        "with_imported" => "true"
      }

      breakdown_params =
        common_params
        |> Map.put("metrics", "visitors,visits,pageviews,visit_duration,bounce_rate")
        |> Map.put("limit", 1000)

      %{key: api_key} = insert(:api_key, user: user)

      conn = put_req_header(conn, "authorization", "Bearer #{api_key}")

      assert_timeseries(conn, common_params)
      assert_pages(conn, common_params)

      assert_sources(conn, breakdown_params)
      assert_utm_mediums(conn, breakdown_params)
      assert_entry_pages(conn, breakdown_params)
      assert_cities(conn, breakdown_params)
      assert_devices(conn, breakdown_params)
      assert_browsers(conn, breakdown_params)
      assert_os(conn, breakdown_params)
      assert_os_versions(conn, breakdown_params)
      assert_active_visitors(site_import)
      assert_custom_events(site_import)
    end

    test "handles rate limiting gracefully", %{user: user, site: site} do
      future = DateTime.add(DateTime.utc_now(), 3600, :second)

      {:ok, job} =
        Plausible.Imported.GoogleAnalytics4.new_import(
          site,
          user,
          label: "properties/123456",
          property: "properties/123456",
          start_date: ~D[2024-01-01],
          end_date: ~D[2024-01-31],
          access_token: "redacted_access_token",
          refresh_token: "redacted_refresh_token",
          token_expires_at: DateTime.to_iso8601(future)
        )

      site_import = Plausible.Imported.get_import(site, job.args.import_id)

      opts = job |> Repo.reload!() |> Map.get(:args) |> GoogleAnalytics4.parse_args()

      opts = Keyword.put(opts, :flush_interval_ms, 10)

      expect(Plausible.HTTPClient.Mock, :post, fn _url, headers, _body, _opts ->
        assert [{"Authorization", "Bearer redacted_access_token"}] == headers
        {:ok, %Finch.Response{status: 200, body: List.first(@full_report_mock)}}
      end)

      expect(Plausible.HTTPClient.Mock, :post, fn _url, headers, _body, _opts ->
        assert [{"Authorization", "Bearer redacted_access_token"}] == headers

        {:error,
         Plausible.HTTPClient.Non200Error.new(%Finch.Response{
           status: 429,
           body: "Rate limit exceeded"
         })}
      end)

      assert {:error, :rate_limit_exceeded, skip_purge?: true, skip_mark_failed?: true} =
               GoogleAnalytics4.import_data(site_import, opts)

      in_65_minutes = DateTime.add(DateTime.utc_now(), 3900, :second)

      assert_enqueued(
        worker: Plausible.Workers.ImportAnalytics,
        args: %{resume_from_import_id: site_import.id},
        scheduled_at: {in_65_minutes, delta: 10}
      )

      [%{args: resume_args}, _] = all_enqueued()

      resume_opts = GoogleAnalytics4.parse_args(resume_args)
      resume_opts = Keyword.put(resume_opts, :flush_interval_ms, 10)
      site_import = Repo.reload!(site_import)

      Enum.each(Plausible.Imported.tables(), fn table ->
        count =
          case table do
            "imported_visitors" -> 31
            "imported_sources" -> 0
            "imported_pages" -> 0
            "imported_entry_pages" -> 0
            "imported_exit_pages" -> 0
            "imported_locations" -> 0
            "imported_devices" -> 0
            "imported_browsers" -> 0
            "imported_operating_systems" -> 0
          end

        query = from(imported in table, where: imported.site_id == ^site.id)
        assert await_clickhouse_count(query, count)
      end)

      for report <- tl(@full_report_mock) do
        expect(Plausible.HTTPClient.Mock, :post, fn _url, headers, _body, _opts ->
          assert [{"Authorization", "Bearer redacted_access_token"}] == headers
          {:ok, %Finch.Response{status: 200, body: report}}
        end)
      end

      assert :ok = GoogleAnalytics4.import_data(site_import, resume_opts)

      Enum.each(Plausible.Imported.tables(), fn table ->
        count =
          case table do
            "imported_sources" -> 210
            "imported_visitors" -> 31
            "imported_pages" -> 3340
            "imported_entry_pages" -> 2934
            "imported_exit_pages" -> 0
            "imported_locations" -> 2291
            "imported_devices" -> 93
            "imported_browsers" -> 233
            "imported_operating_systems" -> 1068
          end

        query = from(imported in table, where: imported.site_id == ^site.id)
        assert await_clickhouse_count(query, count)
      end)
    end
  end

  defp assert_active_visitors(site_import) do
    result =
      ClickhouseRepo.query!(
        "SELECT date, sum(visitors) AS all_visitors, sum(active_visitors) AS all_active_visitors " <>
          "FROM imported_pages WHERE site_id = #{site_import.site_id} AND import_id = #{site_import.id} GROUP BY date"
      )
      |> Map.fetch!(:rows)
      |> Enum.map(fn [date, all_visitors, all_active_visitors] ->
        %{date: date, visitors: all_visitors, active_visitors: all_active_visitors}
      end)

    assert length(result) == 31

    Enum.each(result, fn row ->
      assert row.visitors > 100 and row.active_visitors > 100
      assert row.active_visitors <= row.visitors
    end)

    ClickhouseRepo.query!(
      "SELECT time_on_page FROM imported_pages WHERE active_visitors = 0 AND " <>
        "site_id = #{site_import.site_id} AND import_id = #{site_import.id}"
    )
    |> Map.fetch!(:rows)
    |> Enum.each(fn [time_on_page] ->
      assert time_on_page == 0
    end)
  end

  defp assert_custom_events(site_import) do
    totals =
      ClickhouseRepo.query!(
        "SELECT name, sum(visitors) AS visitors, sum(events) AS events " <>
          "FROM imported_custom_events WHERE site_id = #{site_import.site_id} AND import_id = #{site_import.id} GROUP BY name"
      )
      |> Map.fetch!(:rows)
      |> Enum.map(fn [name, visitors, events] ->
        %{name: name, visitors: visitors, events: events}
      end)
      |> Enum.sort_by(& &1.events)

    breakdown_by_url =
      ClickhouseRepo.query!(
        "SELECT name, link_url, sum(visitors) AS visitors, sum(events) AS events " <>
          "FROM imported_custom_events WHERE site_id = #{site_import.site_id} AND import_id = #{site_import.id} GROUP BY name, link_url"
      )
      |> Map.fetch!(:rows)
      |> Enum.map(fn [name, link_url, visitors, events] ->
        %{name: name, link_url: link_url, visitors: visitors, events: events}
      end)

    assert totals == [
             %{name: "click", events: 17, visitors: 17},
             %{name: "view_search_results", events: 30, visitors: 11},
             %{name: "scroll", events: 2130, visitors: 1513}
           ]

    assert Enum.all?(breakdown_by_url, fn entry ->
             if entry.name == "click" do
               entry.link_url != ""
             else
               entry.link_url == ""
             end
           end)

    assert %{
             name: "click",
             events: 6,
             visitors: 6,
             link_url: "https://www.facebook.com/kuhinjskeprice"
           } in breakdown_by_url
  end

  defp assert_timeseries(conn, params) do
    params =
      Map.put(
        params,
        "metrics",
        "visitors,visits,pageviews,views_per_visit,visit_duration,bounce_rate"
      )

    %{"results" => results} =
      get(conn, "/api/v1/stats/timeseries", params) |> json_response(200)

    assert length(results) == 31

    assert List.first(results) == %{
             "bounce_rate" => 36.0,
             "date" => "2024-01-01",
             "pageviews" => 224,
             "views_per_visit" => 1.14,
             "visit_duration" => 41.0,
             "visitors" => 191,
             "visits" => 197
           }

    assert List.last(results) == %{
             "bounce_rate" => 38.0,
             "date" => "2024-01-31",
             "pageviews" => 195,
             "views_per_visit" => 1.34,
             "visit_duration" => 33.0,
             "visitors" => 141,
             "visits" => 146
           }
  end

  defp assert_sources(conn, params) do
    params = Map.put(params, "property", "visit:source")

    %{"results" => results} =
      get(conn, "/api/v1/stats/breakdown", params) |> json_response(200)

    assert length(results) == 26

    assert List.first(results) == %{
             "bounce_rate" => 35.0,
             "pageviews" => 6229,
             "visit_duration" => 40.0,
             "visitors" => 4671,
             "visits" => 4917,
             "source" => "Google"
           }

    assert List.last(results) == %{
             "bounce_rate" => 100.0,
             "pageviews" => 1,
             "visit_duration" => 0.0,
             "visitors" => 1,
             "visits" => 1,
             "source" => "petalsearch.com"
           }
  end

  defp assert_utm_mediums(conn, params) do
    params = Map.put(params, "property", "visit:utm_medium")

    %{"results" => results} =
      get(conn, "/api/v1/stats/breakdown", params) |> json_response(200)

    assert [
             %{
               "bounce_rate" => 35.0,
               "pageviews" => 6399,
               "utm_medium" => "organic",
               "visit_duration" => 40.0,
               "visitors" => 4787,
               "visits" => 5042
             },
             %{
               "bounce_rate" => 58.0,
               "pageviews" => 491,
               "utm_medium" => "referral",
               "visit_duration" => 27.5,
               "visitors" => 294,
               "visits" => 298
             }
           ] = results
  end

  defp assert_entry_pages(conn, params) do
    params = Map.put(params, "property", "visit:entry_page")

    %{"results" => results} =
      get(conn, "/api/v1/stats/breakdown", params) |> json_response(200)

    assert length(results) == 629

    assert List.first(results) == %{
             "bounce_rate" => 35.0,
             "pageviews" => 838,
             "visit_duration" => 43.1,
             "visitors" => 675,
             "visits" => 712,
             "entry_page" => "/brza-kukuruza"
           }

    assert List.last(results) == %{
             "bounce_rate" => 0.0,
             "pageviews" => 1,
             "visit_duration" => 27.0,
             "visitors" => 1,
             "visits" => 1,
             "entry_page" => "/kad-lisce-pada"
           }
  end

  defp assert_cities(conn, params) do
    params = Map.put(params, "property", "visit:city")

    %{"results" => results} =
      get(conn, "/api/v1/stats/breakdown", params) |> json_response(200)

    assert length(results) == 488

    assert List.first(results) == %{
             "bounce_rate" => 35.0,
             "city" => 792_680,
             "pageviews" => 1650,
             "visit_duration" => 38.9,
             "visitors" => 1233,
             "visits" => 1273
           }

    assert List.last(results) == %{
             "bounce_rate" => 0.0,
             "city" => 4_399_605,
             "pageviews" => 7,
             "visit_duration" => 128.0,
             "visitors" => 1,
             "visits" => 1
           }
  end

  defp assert_devices(conn, params) do
    params = Map.put(params, "property", "visit:device")

    %{"results" => results} =
      get(conn, "/api/v1/stats/breakdown", params) |> json_response(200)

    assert length(results) == 3

    assert List.first(results) == %{
             "bounce_rate" => 38.0,
             "pageviews" => 7041,
             "visit_duration" => 36.6,
             "visitors" => 5277,
             "visits" => 5532,
             "device" => "Mobile"
           }

    assert List.last(results) == %{
             "bounce_rate" => 37.0,
             "pageviews" => 143,
             "visit_duration" => 59.8,
             "visitors" => 97,
             "visits" => 100,
             "device" => "Tablet"
           }
  end

  defp assert_browsers(conn, params) do
    params = Map.put(params, "property", "visit:browser")

    %{"results" => results} =
      get(conn, "/api/v1/stats/breakdown", params) |> json_response(200)

    assert length(results) == 11

    assert List.first(results) == %{
             "bounce_rate" => 33.0,
             "pageviews" => 8143,
             "visit_duration" => 50.2,
             "visitors" => 4625,
             "visits" => 4655,
             "browser" => "Chrome"
           }

    assert List.last(results) == %{
             "bounce_rate" => 0.0,
             "pageviews" => 6,
             "visit_duration" => 0.0,
             "visitors" => 1,
             "visits" => 1,
             "browser" => "Opera Mini"
           }
  end

  defp assert_os(conn, params) do
    params = Map.put(params, "property", "visit:os")

    %{"results" => results} =
      get(conn, "/api/v1/stats/breakdown", params) |> json_response(200)

    assert length(results) == 7

    assert List.first(results) == %{
             "bounce_rate" => 34.0,
             "pageviews" => 5827,
             "visit_duration" => 40.6,
             "visitors" => 4319,
             "visits" => 4495,
             "os" => "Android"
           }

    assert List.last(results) == %{
             "bounce_rate" => 0.0,
             "pageviews" => 6,
             "visit_duration" => 0.0,
             "visitors" => 1,
             "visits" => 1,
             "os" => "(not set)"
           }
  end

  defp assert_os_versions(conn, params) do
    params = Map.put(params, "property", "visit:os_version")

    %{"results" => results} =
      get(conn, "/api/v1/stats/breakdown", params) |> json_response(200)

    assert length(results) == 107

    assert List.first(results) == %{
             "bounce_rate" => 32.0,
             "os" => "Android",
             "os_version" => "13.0.0",
             "pageviews" => 1673,
             "visit_duration" => 42.4,
             "visitors" => 1247,
             "visits" => 1295
           }

    assert List.last(results) == %{
             "bounce_rate" => 0.0,
             "os" => "iOS",
             "os_version" => "15.1",
             "pageviews" => 1,
             "visit_duration" => 54.0,
             "visitors" => 1,
             "visits" => 1
           }
  end

  defp assert_pages(conn, params) do
    metrics = "visitors,visits,pageviews,time_on_page,visit_duration,bounce_rate"

    params =
      params
      |> Map.put("metrics", metrics)
      |> Map.put("limit", 1000)
      |> Map.put("property", "event:page")

    %{"results" => results} =
      get(conn, "/api/v1/stats/breakdown", params) |> json_response(200)

    assert length(results) == 729

    # The `event:page` breakdown is currently using the `entry_page`
    # property to allow querying session metrics.
    #
    # We assert on the 3rd element of the results, because that page
    # was also an entry page somewhere along the queried period. So
    # it will allow us to assert on the session metrics as well.
    assert Enum.at(results, 2) == %{
             "page" => "/",
             "pageviews" => 5537,
             "time_on_page" => 17.677262055264585,
             "visitors" => 371,
             "visits" => 212,
             "bounce_rate" => 54.0,
             "visit_duration" => 45.0
           }

    # This page was never an entry_page in the imported data, and
    # therefore the session metrics are returned as `nil`.
    assert List.last(results) == %{
             "page" => "/5-dobrih-razloga-zasto-zapoceti-dan-zobenom-kasom/",
             "pageviews" => 2,
             "time_on_page" => 10.0,
             "visitors" => 1,
             "visits" => 1,
             "bounce_rate" => nil,
             "visit_duration" => nil
           }
  end
end
