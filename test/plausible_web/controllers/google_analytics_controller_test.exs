defmodule PlausibleWeb.GoogleAnalyticsControllerTest do
  use PlausibleWeb.ConnCase, async: false
  use Oban.Testing, repo: Plausible.Repo

  import Mox

  alias Plausible.Imported.SiteImport

  require Plausible.Imported.SiteImport

  describe "GET /:website/import/google-analytics/property-or-view" do
    setup [:create_user, :log_in, :create_new_site]

    test "lists Google Analytics views", %{conn: conn, site: site} do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn _url, _opts ->
          body = "fixture/ga_list_views.json" |> File.read!() |> Jason.decode!()
          {:ok, %Finch.Response{body: body, status: 200}}
        end
      )

      response =
        conn
        |> get("/#{site.domain}/import/google-analytics/property-or-view", %{
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777",
          "legacy" => "true"
        })
        |> html_response(200)

      assert response =~ "57238190 - one.test"
      assert response =~ "54460083 - two.test"
    end
  end

  describe "POST /:website/settings/google-import" do
    setup [:create_user, :log_in, :create_new_site]

    test "creates Google Analytics 4 site import instance", %{conn: conn, site: site} do
      post(conn, "/#{site.domain}/settings/google-import", %{
        "property_or_view" => "properties/123456",
        "start_date" => "2018-03-01",
        "end_date" => "2022-03-01",
        "access_token" => "token",
        "refresh_token" => "foo",
        "expires_at" => "2022-09-22T20:01:37.112777",
        "legacy" => "false"
      })

      [site_import] = Plausible.Imported.list_all_imports(site)

      assert site_import.source == :google_analytics_4
      assert site_import.end_date == ~D[2022-03-01]
      assert site_import.status == SiteImport.pending()
    end

    test "creates Universal Analytics site import instance", %{conn: conn, site: site} do
      post(conn, "/#{site.domain}/settings/google-import", %{
        "property_or_view" => "123456",
        "start_date" => "2018-03-01",
        "end_date" => "2022-03-01",
        "access_token" => "token",
        "refresh_token" => "foo",
        "expires_at" => "2022-09-22T20:01:37.112777",
        "legacy" => "true"
      })

      [site_import] = Plausible.Imported.list_all_imports(site)

      assert site_import.source == :universal_analytics
      assert site_import.end_date == ~D[2022-03-01]
      assert site_import.status == SiteImport.pending()
    end

    test "schedules a Google Analytics 4 import job in Oban", %{conn: conn, site: site} do
      post(conn, "/#{site.domain}/settings/google-import", %{
        "property_or_view" => "properties/123456",
        "start_date" => "2018-03-01",
        "end_date" => "2022-03-01",
        "access_token" => "token",
        "refresh_token" => "foo",
        "expires_at" => "2022-09-22T20:01:37.112777",
        "legacy" => "false"
      })

      assert [%{id: import_id, legacy: false}] = Plausible.Imported.list_all_imports(site)

      assert_enqueued(
        worker: Plausible.Workers.ImportAnalytics,
        args: %{
          "import_id" => import_id,
          "property" => "properties/123456",
          "start_date" => "2018-03-01",
          "end_date" => "2022-03-01",
          "access_token" => "token",
          "refresh_token" => "foo",
          "token_expires_at" => "2022-09-22T20:01:37.112777"
        }
      )
    end

    test "schedules a Universal Analytics import job in Oban", %{conn: conn, site: site} do
      post(conn, "/#{site.domain}/settings/google-import", %{
        "property_or_view" => "123456",
        "start_date" => "2018-03-01",
        "end_date" => "2022-03-01",
        "access_token" => "token",
        "refresh_token" => "foo",
        "expires_at" => "2022-09-22T20:01:37.112777",
        "legacy" => "true"
      })

      assert [%{id: import_id, legacy: true}] = Plausible.Imported.list_all_imports(site)

      assert_enqueued(
        worker: Plausible.Workers.ImportAnalytics,
        args: %{
          "import_id" => import_id,
          "view_id" => "123456",
          "start_date" => "2018-03-01",
          "end_date" => "2022-03-01",
          "access_token" => "token",
          "refresh_token" => "foo",
          "token_expires_at" => "2022-09-22T20:01:37.112777"
        }
      )
    end
  end
end
