defmodule Plausible.Google.ApiTest do
  use Plausible.DataCase, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Finch
  alias Plausible.Google.Api

  import ExUnit.CaptureLog
  import Mox
  setup :verify_on_exit!

  setup [:create_user, :create_new_site]

  describe "fetch_and_persist/4" do
    @ok_response Jason.decode!(File.read!("fixture/ga_batch_report.json"))
    @no_report_response Jason.decode!(File.read!("fixture/ga_report_empty_rows.json"))

    setup do
      {:ok, pid} = Plausible.Google.Buffer.start_link()
      {:ok, buffer: pid}
    end

    test "will fetch and persist import data from Google Analytics", %{site: site, buffer: buffer} do
      request = %Plausible.Google.ReportRequest{
        dataset: "imported_exit_pages",
        view_id: "123",
        date_range: Date.range(~D[2022-01-01], ~D[2022-02-01]),
        dimensions: ["ga:date", "ga:exitPagePath"],
        metrics: ["ga:users", "ga:exits"],
        access_token: "fake-token",
        page_token: nil,
        page_size: 10_000
      }

      expect(
        Plausible.HTTPClient.Mock,
        :post,
        fn
          "https://analyticsreporting.googleapis.com/v4/reports:batchGet",
          [{"Authorization", "Bearer fake-token"}],
          %{
            reportRequests: [
              %{
                dateRanges: [%{endDate: ~D[2022-02-01], startDate: ~D[2022-01-01]}],
                dimensions: [
                  %{histogramBuckets: [], name: "ga:date"},
                  %{histogramBuckets: [], name: "ga:exitPagePath"}
                ],
                hideTotals: true,
                hideValueRanges: true,
                metrics: [%{expression: "ga:users"}, %{expression: "ga:exits"}],
                orderBys: [%{fieldName: "ga:date", sortOrder: "DESCENDING"}],
                pageSize: 10000,
                pageToken: nil,
                viewId: "123"
              }
            ]
          },
          [receive_timeout: 60_000] ->
            {:ok, %Finch.Response{status: 200, body: @ok_response}}
        end
      )

      Api.fetch_and_persist(site, request,
        sleep_time: 0,
        buffer: buffer
      )

      Plausible.Google.Buffer.flush(buffer)

      assert 1479 ==
               Plausible.ClickhouseRepo.aggregate(
                 from(iex in "imported_exit_pages", where: iex.site_id == ^site.id),
                 :count
               )
    end

    test "retries HTTP request up to 5 times before raising the last error", %{
      site: site,
      buffer: buffer
    } do
      expect(
        Plausible.HTTPClient.Mock,
        :post,
        5,
        fn
          "https://analyticsreporting.googleapis.com/v4/reports:batchGet",
          _,
          _,
          [receive_timeout: 60_000] ->
            Enum.random([
              {:error, %Mint.TransportError{reason: :nxdomain}},
              {:error, %{reason: %Finch.Response{status: 500}}}
            ])
        end
      )

      request = %Plausible.Google.ReportRequest{
        view_id: "123",
        date_range: Date.range(~D[2022-01-01], ~D[2022-02-01]),
        dimensions: ["ga:date"],
        metrics: ["ga:users"],
        access_token: "fake-token",
        page_token: nil,
        page_size: 10_000
      }

      assert {:error, :request_failed} =
               Api.fetch_and_persist(site, request,
                 sleep_time: 0,
                 buffer: buffer
               )
    end

    test "does not fail when report does not have rows key", %{site: site, buffer: buffer} do
      expect(
        Plausible.HTTPClient.Mock,
        :post,
        fn
          "https://analyticsreporting.googleapis.com/v4/reports:batchGet",
          _,
          _,
          [receive_timeout: 60_000] ->
            {:ok, %Finch.Response{status: 200, body: @no_report_response}}
        end
      )

      request = %Plausible.Google.ReportRequest{
        dataset: "imported_exit_pages",
        view_id: "123",
        date_range: Date.range(~D[2022-01-01], ~D[2022-02-01]),
        dimensions: ["ga:date", "ga:exitPagePath"],
        metrics: ["ga:users", "ga:exits"],
        access_token: "fake-token",
        page_token: nil,
        page_size: 10_000
      }

      assert :ok ==
               Api.fetch_and_persist(site, request,
                 sleep_time: 0,
                 buffer: buffer
               )
    end
  end

  describe "fetch_stats/3 errors" do
    setup %{user: user, site: site} do
      insert(:google_auth,
        user: user,
        site: site,
        property: "sc-domain:dummy.test",
        expires: NaiveDateTime.add(NaiveDateTime.utc_now(), 3600)
      )

      :ok
    end

    test "returns generic google_auth_error on 401/403", %{site: site} do
      expect(
        Plausible.HTTPClient.Mock,
        :post,
        fn
          "https://www.googleapis.com/webmasters/v3/sites/sc-domain%3Adummy.test/searchAnalytics/query",
          [{"Authorization", "Bearer 123"}],
          %{
            dimensionFilterGroups: %{},
            dimensions: ["query"],
            endDate: "2022-01-05",
            rowLimit: 5,
            startDate: "2022-01-01"
          } ->
            {:error, %{reason: %Finch.Response{status: Enum.random([401, 403])}}}
        end
      )

      query = %Plausible.Stats.Query{date_range: Date.range(~D[2022-01-01], ~D[2022-01-05])}

      assert {:error, "google_auth_error"} = Plausible.Google.Api.fetch_stats(site, query, 5)
    end

    test "returns whatever error code google returns on API client error", %{site: site} do
      expect(
        Plausible.HTTPClient.Mock,
        :post,
        fn
          "https://www.googleapis.com/webmasters/v3/sites/sc-domain%3Adummy.test/searchAnalytics/query",
          _,
          _ ->
            {:error, %{reason: %Finch.Response{status: 400, body: %{"error" => "some_error"}}}}
        end
      )

      query = %Plausible.Stats.Query{date_range: Date.range(~D[2022-01-01], ~D[2022-01-05])}

      assert {:error, "some_error"} = Plausible.Google.Api.fetch_stats(site, query, 5)
    end

    test "returns generic HTTP error and logs it", %{site: site} do
      expect(
        Plausible.HTTPClient.Mock,
        :post,
        fn
          "https://www.googleapis.com/webmasters/v3/sites/sc-domain%3Adummy.test/searchAnalytics/query",
          _,
          _ ->
            {:error, Finch.Error.exception(:some_reason)}
        end
      )

      query = %Plausible.Stats.Query{date_range: Date.range(~D[2022-01-01], ~D[2022-01-05])}

      log =
        capture_log(fn ->
          assert {:error, "failed_to_list_stats"} =
                   Plausible.Google.Api.fetch_stats(site, query, 5)
        end)

      assert log =~ "Google Analytics: failed to list stats: %Finch.Error{reason: :some_reason}"
    end
  end

  describe "fetch_stats/3 with VCR cassetes" do
    # We need real HTTP Client for VCR tests
    setup_patch_env(:http_impl, Plausible.HTTPClient)

    test "returns name and visitor count", %{user: user, site: site} do
      use_cassette "google_analytics_stats", match_requests_on: [:request_body] do
        insert(:google_auth,
          user: user,
          site: site,
          property: "sc-domain:dummy.test",
          expires: NaiveDateTime.add(NaiveDateTime.utc_now(), 3600)
        )

        query = %Plausible.Stats.Query{date_range: Date.range(~D[2022-01-01], ~D[2022-01-05])}

        assert {:ok,
                [
                  %{name: ["keyword1", "keyword2"], visitors: 25},
                  %{name: ["keyword3", "keyword4"], visitors: 15}
                ]} = Plausible.Google.Api.fetch_stats(site, query, 5)
      end
    end

    test "returns next page when page argument is set", %{user: user, site: site} do
      use_cassette "google_analytics_stats#with_page", match_requests_on: [:request_body] do
        insert(:google_auth,
          user: user,
          site: site,
          property: "sc-domain:dummy.test",
          expires: NaiveDateTime.add(NaiveDateTime.utc_now(), 3600)
        )

        query = %Plausible.Stats.Query{
          filters: %{"page" => 5},
          date_range: Date.range(~D[2022-01-01], ~D[2022-01-05])
        }

        assert {:ok,
                [
                  %{name: ["keyword1", "keyword2"], visitors: 25},
                  %{name: ["keyword3", "keyword4"], visitors: 15}
                ]} = Plausible.Google.Api.fetch_stats(site, query, 5)
      end
    end

    test "defaults first page when page argument is not set", %{user: user, site: site} do
      use_cassette "google_analytics_stats#without_page", match_requests_on: [:request_body] do
        insert(:google_auth,
          user: user,
          site: site,
          property: "sc-domain:dummy.test",
          expires: NaiveDateTime.add(NaiveDateTime.utc_now(), 3600)
        )

        query = %Plausible.Stats.Query{date_range: Date.range(~D[2022-01-01], ~D[2022-01-05])}

        assert {:ok,
                [
                  %{name: ["keyword1", "keyword2"], visitors: 25},
                  %{name: ["keyword3", "keyword4"], visitors: 15}
                ]} = Plausible.Google.Api.fetch_stats(site, query, 5)
      end
    end

    test "returns error when token refresh fails", %{user: user, site: site} do
      use_cassette "google_analytics_auth#invalid_grant" do
        insert(:google_auth,
          user: user,
          site: site,
          property: "sc-domain:dummy.test",
          access_token: "*****",
          refresh_token: "*****",
          expires: NaiveDateTime.add(NaiveDateTime.utc_now(), -3600)
        )

        query = %Plausible.Stats.Query{date_range: Date.range(~D[2022-01-01], ~D[2022-01-05])}

        assert {:error, "invalid_grant"} = Plausible.Google.Api.fetch_stats(site, query, 5)
      end
    end
  end
end
