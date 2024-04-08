defmodule Plausible.Imported.GoogleAnalytics4Test do
  use Plausible.DataCase, async: true

  import Mox

  import Ecto.Query, only: [from: 2]

  alias Plausible.Imported.GoogleAnalytics4

  @refresh_token_body Jason.decode!(File.read!("fixture/ga_refresh_token.json"))

  @full_report_mock [
                      "fixture/ga4_report_imported_visitors.json",
                      "fixture/ga4_report_imported_sources.json",
                      "fixture/ga4_report_imported_pages.json",
                      "fixture/ga4_report_imported_entry_pages.json",
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

    test "imports data returned from GA4 Data API", %{user: user, site: site} do
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
            "imported_sources" -> 1090
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
end
