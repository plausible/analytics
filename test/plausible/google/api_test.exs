defmodule Plausible.Google.APITest do
  use Plausible.DataCase, async: true
  use Plausible.Test.Support.HTTPMocker

  alias Plausible.Google
  alias Plausible.Stats.{DateTimeRange, Query}

  import ExUnit.CaptureLog
  import Mox
  setup :verify_on_exit!

  setup [:create_user, :create_site]

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
            dimensionFilterGroups: [],
            dimensions: ["query"],
            endDate: "2022-01-05",
            rowLimit: 5,
            startRow: 0,
            startDate: "2022-01-01"
          } ->
            {:error, %{reason: %Finch.Response{status: Enum.random([401, 403])}}}
        end
      )

      query =
        Query.from(site, %{"period" => "custom", "from" => "2022-01-01", "to" => "2022-01-05"})

      assert {:error, "google_auth_error"} = Google.API.fetch_stats(site, query, {5, 0}, "")
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

      query =
        Query.from(site, %{"period" => "custom", "from" => "2022-01-01", "to" => "2022-01-05"})

      assert {:error, "some_error"} = Google.API.fetch_stats(site, query, {5, 0}, "")
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

      query =
        Query.from(site, %{"period" => "custom", "from" => "2022-01-01", "to" => "2022-01-05"})

      log =
        capture_log(fn ->
          assert {:error, "failed_to_list_stats"} =
                   Google.API.fetch_stats(site, query, {5, 0}, "")
        end)

      assert log =~
               "Google Search Console: failed to list stats: %Finch.Error{reason: :some_reason}"
    end
  end

  test "returns error when token refresh fails", %{user: user, site: site} do
    mock_http_with("google_auth#invalid_grant.json")

    insert(:google_auth,
      user: user,
      site: site,
      property: "sc-domain:dummy.test",
      access_token: "*****",
      refresh_token: "*****",
      expires: NaiveDateTime.add(NaiveDateTime.utc_now(), -3600)
    )

    query =
      Query.from(site, %{"period" => "custom", "from" => "2022-01-01", "to" => "2022-01-05"})

    assert {:error, "invalid_grant"} = Google.API.fetch_stats(site, query, 5, "")
  end

  test "returns error when google auth not configured", %{site: site} do
    time_range = DateTimeRange.new!(~U[2022-01-01 00:00:00Z], ~U[2022-01-05 23:59:59Z])
    query = %Plausible.Stats.Query{utc_time_range: time_range}

    assert {:error, :google_property_not_configured} = Google.API.fetch_stats(site, query, 5, "")
  end

  describe "fetch_stats/3 with valid auth" do
    setup %{user: user, site: site} do
      insert(:google_auth,
        user: user,
        site: site,
        property: "sc-domain:dummy.test",
        expires: NaiveDateTime.add(NaiveDateTime.utc_now(), 3600)
      )

      :ok
    end

    test "returns name and visitor count", %{site: site} do
      mock_http_with("google_search_console.json")

      query =
        Query.from(site, %{"period" => "custom", "from" => "2022-01-01", "to" => "2022-01-05"})

      assert {:ok,
              [
                %{name: "keyword1", visitors: 25, ctr: 36.8, impressions: 50, position: 2.2},
                %{name: "keyword3", visitors: 15}
              ]} = Google.API.fetch_stats(site, query, {5, 0}, "")
    end

    test "transforms page filters to search console format", %{site: site} do
      expect(
        Plausible.HTTPClient.Mock,
        :post,
        fn
          "https://www.googleapis.com/webmasters/v3/sites/sc-domain%3Adummy.test/searchAnalytics/query",
          [{"Authorization", "Bearer 123"}],
          %{
            dimensionFilterGroups: [
              %{filters: [%{expression: "https://dummy.test/page", dimension: "page"}]}
            ],
            dimensions: ["query"],
            endDate: "2022-01-05",
            rowLimit: 5,
            startRow: 0,
            startDate: "2022-01-01"
          } ->
            {:ok, %Finch.Response{status: 200, body: %{"rows" => []}}}
        end
      )

      query =
        Plausible.Stats.Query.from(site, %{
          "period" => "custom",
          "from" => "2022-01-01",
          "to" => "2022-01-05",
          "filters" => "event:page==/page"
        })

      assert {:ok, []} = Google.API.fetch_stats(site, query, {5, 0}, "")
    end

    test "returns :invalid filters when using filters that cannot be used in Search Console", %{
      site: site
    } do
      query =
        Plausible.Stats.Query.from(site, %{
          "period" => "custom",
          "from" => "2022-01-01",
          "to" => "2022-01-05",
          "filters" => "event:goal==Signup"
        })

      assert {:error, :unsupported_filters} = Google.API.fetch_stats(site, query, 5, "")
    end
  end
end
