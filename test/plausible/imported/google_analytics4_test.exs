defmodule Plausible.Imported.GoogleAnalytics4Test do
  use PlausibleWeb.ConnCase, async: true
  use Plausible
  use Oban.Testing, repo: Plausible.Repo

  import Mox
  import Ecto.Query, only: [from: 2]
  import ExUnit.CaptureLog

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

  on_ce do
    @moduletag :capture_log
  end

  setup :verify_on_exit!

  describe "parse_args/1 and import_data/2" do
    setup [:create_user, :create_site]

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
        |> Map.put("metrics", "visitors,visits,visit_duration,bounce_rate")
        |> Map.put("limit", 1000)

      %{key: api_key} = insert(:api_key, user: user)

      conn = put_req_header(conn, "authorization", "Bearer #{api_key}")

      insert(:goal, event_name: "Outbound Link: Click", site: site)
      insert(:goal, event_name: "view_search_results", site: site)
      insert(:goal, event_name: "scroll", site: site)

      # Timeseries
      assert_timeseries(conn, common_params)

      # Breakdown (event:*)
      assert_pages(conn, common_params)
      assert_custom_events(conn, common_params)
      assert_outbound_link_urls(conn, common_params)

      # Breakdown (visit:*)
      assert_sources(conn, breakdown_params)
      assert_utm_mediums(conn, breakdown_params)
      assert_entry_pages(conn, breakdown_params)
      assert_cities(conn, breakdown_params)
      assert_devices(conn, breakdown_params)
      assert_browsers(conn, breakdown_params)
      assert_os(conn, breakdown_params)
      assert_os_versions(conn, breakdown_params)
    end

    test "handles empty response payload gracefully", %{user: user, site: site} do
      future = DateTime.add(DateTime.utc_now(), 3600, :second)

      empty_custom_events = %{
        "reports" => [
          %{
            "dimensionHeaders" => [
              %{"name" => "date"},
              %{"name" => "eventName"},
              %{"name" => "linkUrl"}
            ],
            "kind" => "analyticsData#runReport",
            "metadata" => %{"currencyCode" => "USD", "timeZone" => "Etc/GMT"},
            "metricHeaders" => [
              %{"name" => "totalUsers", "type" => "TYPE_INTEGER"},
              %{"name" => "eventCount", "type" => "TYPE_INTEGER"}
            ]
          }
        ]
      }

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

      for report <- Enum.take(@full_report_mock, 4) do
        expect(Plausible.HTTPClient.Mock, :post, fn _url, headers, _body, _opts ->
          assert [{"Authorization", "Bearer redacted_access_token"}] == headers
          {:ok, %Finch.Response{status: 200, body: report}}
        end)
      end

      expect(Plausible.HTTPClient.Mock, :post, fn _url, headers, _body, _opts ->
        assert [{"Authorization", "Bearer redacted_access_token"}] == headers
        {:ok, %Finch.Response{status: 200, body: empty_custom_events}}
      end)

      for report <- Enum.drop(@full_report_mock, 5) do
        expect(Plausible.HTTPClient.Mock, :post, fn _url, headers, _body, _opts ->
          assert [{"Authorization", "Bearer redacted_access_token"}] == headers
          {:ok, %Finch.Response{status: 200, body: report}}
        end)
      end

      assert :ok = GoogleAnalytics4.import_data(site_import, opts)

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
            "imported_custom_events" -> 0
          end

        query = from(imported in table, where: imported.site_id == ^site.id)
        assert await_clickhouse_count(query, count)
      end)
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
            "imported_custom_events" -> 0
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
            "imported_custom_events" -> 56
          end

        query = from(imported in table, where: imported.site_id == ^site.id)
        assert await_clickhouse_count(query, count)
      end)
    end

    @recoverable_errors [
      {
        Macro.escape(
          Plausible.HTTPClient.Non200Error.new(%Finch.Response{
            status: 500,
            body: "Internal server error"
          })
        ),
        :server_failed,
        ~s|Request failed for imported_sources with code 500: "Internal server error"|
      },
      {
        :timeout,
        :socket_failed,
        ~s|Request failed for imported_sources: :timeout|
      }
    ]

    for {error_mock, error_returned, log_message} <- @recoverable_errors do
      test "handles #{error_returned} gracefully", %{user: user, site: site} do
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

        opts =
          opts
          |> Keyword.put(:flush_interval_ms, 10)
          |> Keyword.put(:fetch_opts, max_attempts: 2, sleep_time: 50)

        expect(Plausible.HTTPClient.Mock, :post, fn _url, headers, _body, _opts ->
          assert [{"Authorization", "Bearer redacted_access_token"}] == headers
          {:ok, %Finch.Response{status: 200, body: List.first(@full_report_mock)}}
        end)

        expect(Plausible.HTTPClient.Mock, :post, 2, fn _url, headers, _body, _opts ->
          assert [{"Authorization", "Bearer redacted_access_token"}] == headers

          {:error, unquote(error_mock)}
        end)

        assert capture_log(fn ->
                 assert {:error, unquote(error_returned),
                         skip_purge?: true, skip_mark_failed?: true} =
                          GoogleAnalytics4.import_data(site_import, opts)
               end) =~ unquote(log_message)

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
              "imported_custom_events" -> 0
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
              "imported_custom_events" -> 56
            end

          query = from(imported in table, where: imported.site_id == ^site.id)
          assert await_clickhouse_count(query, count)
        end)
      end
    end
  end

  defp assert_custom_events(conn, params) do
    params =
      params
      |> Map.put("metrics", "visitors,events,conversion_rate")
      |> Map.put("property", "event:goal")

    %{"results" => results} =
      get(conn, "/api/v1/stats/breakdown", params) |> json_response(200)

    assert results == [
             %{
               "goal" => "scroll",
               "visitors" => 1513,
               "events" => 2130,
               "conversion_rate" => 24.69
             },
             %{
               "goal" => "Outbound Link: Click",
               "visitors" => 17,
               "events" => 17,
               "conversion_rate" => 0.28
             },
             %{
               "goal" => "view_search_results",
               "visitors" => 11,
               "events" => 30,
               "conversion_rate" => 0.18
             }
           ]
  end

  defp assert_outbound_link_urls(conn, params) do
    params =
      Map.merge(params, %{
        "metrics" => "visitors,events,conversion_rate",
        "property" => "event:props:url",
        "filters" => "event:goal==Outbound Link: Click"
      })

    %{"results" => results} =
      get(conn, "/api/v1/stats/breakdown", params) |> json_response(200)

    assert length(results) == 10

    assert List.first(results) ==
             %{
               "url" => "https://www.facebook.com/kuhinjskeprice",
               "visitors" => 6,
               "conversion_rate" => 0.1,
               "events" => 6
             }

    results
    |> Enum.find(
      &(&1["url"] ==
          "http://www.jamieoliver.com/recipes/pasta-recipes/spinach-ricotta-cannelloni/")
    )
    |> then(fn page ->
      assert %{"visitors" => 1, "conversion_rate" => 0.02, "events" => 1} = page
    end)
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
             "visit_duration" => 40.0,
             "visitors" => 4671,
             "visits" => 4917,
             "source" => "Google"
           }

    assert List.last(results) == %{
             "bounce_rate" => 0.0,
             "source" => "yahoo",
             "visit_duration" => 41.0,
             "visitors" => 1,
             "visits" => 1
           }
  end

  defp assert_utm_mediums(conn, params) do
    params = Map.put(params, "property", "visit:utm_medium")

    %{"results" => results} =
      get(conn, "/api/v1/stats/breakdown", params) |> json_response(200)

    assert [
             %{
               "bounce_rate" => 35.0,
               "utm_medium" => "organic",
               "visit_duration" => 40.0,
               "visitors" => 4787,
               "visits" => 5042
             },
             %{
               "bounce_rate" => 58.0,
               "utm_medium" => "referral",
               "visit_duration" => 27.0,
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
             "visit_duration" => 43.0,
             "visitors" => 675,
             "visits" => 712,
             "entry_page" => "/brza-kukuruza"
           }

    assert List.last(results) == %{
             "bounce_rate" => 0.0,
             "entry_page" => "/znamenitosti-rima-koje-treba-vidjeti",
             "visit_duration" => 40.0,
             "visitors" => 1,
             "visits" => 1
           }
  end

  defp assert_cities(conn, params) do
    params = Map.put(params, "property", "visit:city")

    %{"results" => results} =
      get(conn, "/api/v1/stats/breakdown", params) |> json_response(200)

    assert length(results) == 494

    assert List.first(results) == %{
             "bounce_rate" => 35.0,
             "city" => 792_680,
             "visit_duration" => 39.0,
             "visitors" => 1233,
             "visits" => 1273
           }

    assert List.last(results) == %{
             "bounce_rate" => 0.0,
             "city" => 11_951_298,
             "visit_duration" => 271.0,
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
             "visit_duration" => 37.0,
             "visitors" => 5277,
             "visits" => 5532,
             "device" => "Mobile"
           }

    assert List.last(results) == %{
             "bounce_rate" => 37.0,
             "visit_duration" => 60.0,
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
             "visit_duration" => 50.0,
             "visitors" => 4625,
             "visits" => 4655,
             "browser" => "Chrome"
           }

    assert List.last(results) == %{
             "bounce_rate" => 0.0,
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
             "visit_duration" => 41.0,
             "visitors" => 4319,
             "visits" => 4495,
             "os" => "Android"
           }

    assert List.last(results) == %{
             "bounce_rate" => 0.0,
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
             "visit_duration" => 42.0,
             "visitors" => 1247,
             "visits" => 1295
           }

    assert List.last(results) == %{
             "bounce_rate" => 0.0,
             "os" => "Chrome OS",
             "os_version" => "x86_64 15662.76.0",
             "visit_duration" => 16.0,
             "visitors" => 1,
             "visits" => 1
           }
  end

  defp assert_pages(conn, params) do
    metrics = "visitors,visits,time_on_page,visit_duration,bounce_rate"

    params =
      params
      |> Map.put("metrics", metrics)
      |> Map.put("limit", 1000)
      |> Map.put("property", "event:page")

    %{"results" => results} =
      get(conn, "/api/v1/stats/breakdown", params) |> json_response(200)

    assert length(results) == 730

    # The `event:page` breakdown is currently using the `entry_page`
    # property to allow querying session metrics.
    #
    # We assert on the 3rd element of the results, because that page
    # was also an entry page somewhere along the queried period. So
    # it will allow us to assert on the session metrics as well.
    assert Enum.at(results, 2) == %{
             "page" => "/",
             "time_on_page" => 462,
             "visitors" => 371,
             "visits" => 212,
             "bounce_rate" => 54.0,
             "visit_duration" => 45.0
           }

    # This page was never an entry_page in the imported data, and
    # therefore the session metrics are returned as `nil`.
    assert List.last(results) == %{
             "bounce_rate" => 0.0,
             "page" => "/znamenitosti-rima-koje-treba-vidjeti/",
             "time_on_page" => 40,
             "visit_duration" => 0.0,
             "visitors" => 1,
             "visits" => 1
           }
  end
end
