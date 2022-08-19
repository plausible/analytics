defmodule Plausible.Google.ApiTest do
  use Plausible.DataCase, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Finch
  alias Plausible.Google.Api
  import Plausible.TestUtils
  import Double

  setup [:create_user, :create_new_site]

  describe "fetch_and_persist/4" do
    @ok_response File.read!("fixture/ga_batch_report.json")

    setup do
      {:ok, pid} = Plausible.Google.Buffer.start_link()
      {:ok, buffer: pid}
    end

    test "will fetch and persist import data from Google Analytics", %{site: site, buffer: buffer} do
      finch_double =
        Finch
        |> stub(:request, fn _, _ ->
          {:ok, %Finch.Response{status: 200, body: @ok_response}}
        end)

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

      Api.fetch_and_persist(site, request,
        http_client: finch_double,
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
      finch_double =
        Finch
        |> stub(:request, fn _, _ -> {:error, :timeout} end)
        |> stub(:request, fn _, _ -> {:error, :nx_domain} end)
        |> stub(:request, fn _, _ -> {:error, :closed} end)
        |> stub(:request, fn _, _ -> {:ok, %Finch.Response{status: 503}} end)
        |> stub(:request, fn _, _ -> {:ok, %Finch.Response{status: 502}} end)

      request = %Plausible.Google.ReportRequest{
        view_id: "123",
        date_range: Date.range(~D[2022-01-01], ~D[2022-02-01]),
        dimensions: ["ga:date"],
        metrics: ["ga:users"],
        access_token: "fake-token",
        page_token: nil,
        page_size: 10_000
      }

      assert_raise RuntimeError, "Google API request failed too many times", fn ->
        Api.fetch_and_persist(site, request,
          http_client: finch_double,
          sleep_time: 0,
          buffer: buffer
        )
      end

      assert_receive({Finch, :request, [_, _]})
      assert_receive({Finch, :request, [_, _]})
      assert_receive({Finch, :request, [_, _]})
      assert_receive({Finch, :request, [_, _]})
      assert_receive({Finch, :request, [_, _]})
    end

    test "does not fail when report does not have rows key", %{site: site, buffer: buffer} do
      finch_double =
        Finch
        |> stub(:request, fn _, _ ->
          {:ok,
           %Finch.Response{status: 200, body: File.read!("fixture/ga_report_empty_rows.json")}}
        end)

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
                 http_client: finch_double,
                 sleep_time: 0,
                 buffer: buffer
               )
    end
  end

  describe "fetch_stats/3" do
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
