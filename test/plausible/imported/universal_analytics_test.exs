defmodule Plausible.Imported.UniversalAnalyticsTest do
  use Plausible.DataCase, async: true
  use Plausible.Test.Support.HTTPMocker

  alias Plausible.Imported.UniversalAnalytics

  setup [:create_user, :create_new_site]

  describe "create_job/2 and parse_args/1" do
    test "parses job args properly" do
      site = insert(:site)
      site_id = site.id
      expires_at = NaiveDateTime.to_iso8601(NaiveDateTime.utc_now())

      job =
        UniversalAnalytics.create_job(site,
          view_id: 123,
          start_date: "2023-10-01",
          end_date: "2024-01-02",
          access_token: "access123",
          refresh_token: "refresh123",
          token_expires_at: expires_at
        )

      assert %Ecto.Changeset{
               data: %Oban.Job{},
               changes: %{
                 args:
                   %{
                     "site_id" => ^site_id,
                     "view_id" => 123,
                     "start_date" => "2023-10-01",
                     "end_date" => "2024-01-02",
                     "access_token" => "access123",
                     "refresh_token" => "refresh123",
                     "token_expires_at" => ^expires_at
                   } = args
               }
             } = job

      assert opts = [_ | _] = UniversalAnalytics.parse_args(args)

      assert opts[:view_id] == 123
      assert opts[:date_range] == Date.range(~D[2023-10-01], ~D[2024-01-02])
      assert opts[:auth] == {"access123", "refresh123", expires_at}
    end
  end

  describe "import/2" do
    @tag :slow
    test "imports page views from Google Analytics", %{site: site} do
      mock_http_with("google_analytics_import#1.json")

      view_id = "54297898"
      date_range = Date.range(~D[2011-01-01], ~D[2022-07-19])

      future = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_iso8601()
      auth = {"***", "refresh_token", future}

      assert :ok ==
               UniversalAnalytics.import(site,
                 date_range: date_range,
                 view_id: view_id,
                 auth: auth
               )

      assert 1_495_150 == Plausible.Stats.Clickhouse.imported_pageview_count(site)
    end
  end
end
