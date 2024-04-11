defmodule Plausible.DataMigration.GenerateLocalImported do
  import Mox

  import Plausible.Factory

  alias Plausible.Repo
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

  Mox.defmock(Plausible.HTTPClient.Mock, for: Plausible.HTTPClient.Interface)

  def run() do
    user = insert(:user, email: "needsto@be.unique")
    site = insert(:site, members: [user], domain: "also.unique")
    IO.inspect(site.id, label: "Generating imported data per fixtures for site_id")

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

    opts = job |> Repo.reload!() |> Map.get(:args) |> GoogleAnalytics4.parse_args()

    opts = Keyword.put(opts, :flush_interval_ms, 10)

    expect(Plausible.HTTPClient.Mock, :post, fn "https://www.googleapis.com/oauth2/v4/token",
                                              _headers,
                                              _body ->
      {:ok, %Finch.Response{status: 200, body: @refresh_token_body}}
    end)

    for report <- @full_report_mock do
      expect(Plausible.HTTPClient.Mock, :post, fn _url, _headers, _body, _opts ->
        {:ok, %Finch.Response{status: 200, body: report}}
      end)
    end

    :ok = GoogleAnalytics4.import_data(site_import, opts)

    site_import
    |> Plausible.Imported.SiteImport.complete_changeset()
    |> Repo.update!()

    IO.inspect(site_import.id, label: "site_import created with import_id")
  end
end
