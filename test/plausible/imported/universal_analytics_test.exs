defmodule Plausible.Imported.UniversalAnalyticsTest do
  use Plausible.DataCase, async: true
  use Plausible.Test.Support.HTTPMocker

  alias Plausible.Imported.UniversalAnalytics

  setup [:create_user, :create_new_site]

  describe "new_import/3 and parse_args/1" do
    test "parses job args properly", %{user: user, site: site} do
      expires_at = NaiveDateTime.to_iso8601(NaiveDateTime.utc_now())

      assert {:ok, job} =
               UniversalAnalytics.new_import(site, user,
                 view_id: 123,
                 start_date: "2023-10-01",
                 end_date: "2024-01-02",
                 access_token: "access123",
                 refresh_token: "refresh123",
                 token_expires_at: expires_at
               )

      assert %Oban.Job{
               args:
                 %{
                   "import_id" => import_id,
                   "view_id" => 123,
                   "start_date" => "2023-10-01",
                   "end_date" => "2024-01-02",
                   "access_token" => "access123",
                   "refresh_token" => "refresh123",
                   "token_expires_at" => ^expires_at
                 } = args
             } = Repo.reload!(job)

      assert [
               %{
                 id: ^import_id,
                 source: :universal_analytics,
                 start_date: ~D[2023-10-01],
                 end_date: ~D[2024-01-02],
                 status: :pending
               }
             ] = Plausible.Imported.list_all_imports(site)

      assert %{
               imported_data: %{
                 source: "Google Analytics",
                 start_date: ~D[2023-10-01],
                 end_date: ~D[2024-01-02],
                 status: "importing"
               }
             } = Repo.reload!(site)

      assert opts = [_ | _] = UniversalAnalytics.parse_args(args)

      assert opts[:view_id] == 123
      assert opts[:date_range] == Date.range(~D[2023-10-01], ~D[2024-01-02])
      assert opts[:auth] == {"access123", "refresh123", expires_at}
    end
  end

  describe "import_data/2" do
    @tag :slow
    test "imports page views from Google Analytics", %{user: user, site: site} do
      mock_http_with("google_analytics_import#1.json")

      view_id = "54297898"
      date_range = Date.range(~D[2011-01-01], ~D[2022-07-19])

      future = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_iso8601()
      auth = {"***", "refresh_token", future}

      site_import =
        site
        |> Plausible.Imported.SiteImport.create_changeset(
          user,
          %{source: :universal_analytics, start_date: date_range.first, end_date: date_range.last}
        )
        |> Plausible.Repo.insert!()

      assert :ok ==
               UniversalAnalytics.import_data(site_import,
                 date_range: date_range,
                 view_id: view_id,
                 auth: auth
               )

      assert 1_495_150 == Plausible.Stats.Clickhouse.imported_pageview_count(site)
    end
  end
end
