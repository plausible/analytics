defmodule PlausibleWeb.GoogleAnalyticsControllerTest do
  use PlausibleWeb.ConnCase, async: false
  use Oban.Testing, repo: Plausible.Repo

  import Mox
  import Plausible.Test.Support.HTML

  alias Plausible.HTTPClient
  alias Plausible.Imported.SiteImport

  require Plausible.Imported.SiteImport

  if Plausible.ce?() do
    @moduletag :capture_log
  end

  setup :verify_on_exit!

  describe "GET /:domain/import/google-analytics/property" do
    setup [:create_user, :log_in, :create_site]

    test "lists Google Analytics properties", %{conn: conn, site: site} do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn _url, _opts ->
          body = "fixture/ga4_list_properties.json" |> File.read!() |> Jason.decode!()
          {:ok, %Finch.Response{body: body, status: 200}}
        end
      )

      response =
        conn
        |> get("/#{site.domain}/import/google-analytics/property", %{
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777"
        })
        |> html_response(200)

      assert response =~ "account.one - GA4 (properties/428685906)"
      assert response =~ "GA4 - Flood-It! (properties/153293282)"
      assert response =~ "GA4 - Google Merch Shop (properties/213025502)"
    end

    test "redirects to imports and exports on rate limit error with flash error", %{
      conn: conn,
      site: site
    } do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn _url, _opts ->
          {:error, %HTTPClient.Non200Error{reason: %{status: 429, body: "rate limit exceeded"}}}
        end
      )

      conn =
        conn
        |> get("/#{site.domain}/import/google-analytics/property", %{
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777"
        })

      assert redirected_to(conn, 302) ==
               PlausibleWeb.Router.Helpers.site_path(
                 conn,
                 :settings_imports_exports,
                 site.domain
               )

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Google Analytics rate limit has been exceeded. Please try again later."
    end

    test "redirects to imports and exports on auth error with flash error", %{
      conn: conn,
      site: site
    } do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn _url, _opts ->
          {:error, %HTTPClient.Non200Error{reason: %{status: 403, body: %{}}}}
        end
      )

      conn =
        conn
        |> get("/#{site.domain}/import/google-analytics/property", %{
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777"
        })

      assert redirected_to(conn, 302) ==
               PlausibleWeb.Router.Helpers.site_path(
                 conn,
                 :settings_imports_exports,
                 site.domain
               )

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "We were unable to authenticate your Google Analytics account"
    end

    @tag :ce_build_only
    test "redirects to imports and exports on disabled API with flash error", %{
      conn: conn,
      site: site
    } do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn _url, _opts ->
          body = "fixture/ga4_api_disabled_error.json" |> File.read!() |> Jason.decode!()
          {:error, %HTTPClient.Non200Error{reason: %{status: 403, body: body}}}
        end
      )

      conn =
        conn
        |> get("/#{site.domain}/import/google-analytics/property", %{
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777"
        })

      assert redirected_to(conn, 302) ==
               PlausibleWeb.Router.Helpers.site_path(
                 conn,
                 :settings_imports_exports,
                 site.domain
               )

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               """
               Google Analytics Admin API has not been used in project 752168887897 before or it is disabled. \
               Enable it by visiting https://console.developers.google.com/apis/api/analyticsadmin.googleapis.com/overview?project=752168887897 then retry. \
               If you enabled this API recently, wait a few minutes for the action to propagate to our systems and retry.\
               """
    end

    test "redirects to imports and exports on timeout error with flash error", %{
      conn: conn,
      site: site
    } do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn _url, _opts ->
          {:error, %Mint.TransportError{reason: :timeout}}
        end
      )

      conn =
        conn
        |> get("/#{site.domain}/import/google-analytics/property", %{
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777"
        })

      assert redirected_to(conn, 302) ==
               PlausibleWeb.Router.Helpers.site_path(
                 conn,
                 :settings_imports_exports,
                 site.domain
               )

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Google Analytics API has timed out."
    end

    test "redirects to imports and exports on list retrieval failure with flash error",
         %{
           conn: conn,
           site: site
         } do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn _url, _opts ->
          {:error, %HTTPClient.Non200Error{reason: %{status: 500, body: "Internal server error"}}}
        end
      )

      conn =
        conn
        |> get("/#{site.domain}/import/google-analytics/property", %{
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777"
        })

      assert redirected_to(conn, 302) ==
               PlausibleWeb.Router.Helpers.site_path(
                 conn,
                 :settings_imports_exports,
                 site.domain
               )

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "We were unable to list your Google Analytics properties"
    end
  end

  describe "POST /:domain/import/google-analytics/property" do
    setup [:create_user, :log_in, :create_site]

    test "redirects to confirmation", %{conn: conn, site: site} do
      expect(
        Plausible.HTTPClient.Mock,
        :post,
        fn _url, _opts, _params ->
          body = "fixture/ga4_start_date.json" |> File.read!() |> Jason.decode!()
          {:ok, %Finch.Response{body: body, status: 200}}
        end
      )

      expect(
        Plausible.HTTPClient.Mock,
        :post,
        fn _url, _opts, _params ->
          body = "fixture/ga4_end_date.json" |> File.read!() |> Jason.decode!()
          {:ok, %Finch.Response{body: body, status: 200}}
        end
      )

      conn =
        conn
        |> post("/#{site.domain}/import/google-analytics/property", %{
          "property" => "properties/428685906",
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777"
        })

      assert redirected_to(conn, 302) =~
               "/#{URI.encode_www_form(site.domain)}/import/google-analytics/confirm"
    end

    test "renders error when no time window to import available", %{conn: conn, site: site} do
      start_date = ~D[2022-01-12]
      end_date = ~D[2024-03-13]

      _existing_import =
        insert(:site_import,
          site: site,
          start_date: start_date,
          end_date: end_date,
          status: :completed
        )

      expect(
        Plausible.HTTPClient.Mock,
        :post,
        fn _url, _opts, _params ->
          body = "fixture/ga4_start_date.json" |> File.read!() |> Jason.decode!()
          {:ok, %Finch.Response{body: body, status: 200}}
        end
      )

      expect(
        Plausible.HTTPClient.Mock,
        :post,
        fn _url, _opts, _params ->
          body = "fixture/ga4_end_date.json" |> File.read!() |> Jason.decode!()
          {:ok, %Finch.Response{body: body, status: 200}}
        end
      )

      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn _url, _opts ->
          body = "fixture/ga4_list_properties.json" |> File.read!() |> Jason.decode!()
          {:ok, %Finch.Response{body: body, status: 200}}
        end
      )

      response =
        conn
        |> post("/#{site.domain}/import/google-analytics/property", %{
          "property" => "properties/428685906",
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777"
        })
        |> html_response(200)

      assert response =~
               "Imported data time range is completely overlapping with existing data. Nothing to import."
    end

    test "renders error when there's no data to import", %{conn: conn, site: site} do
      expect(
        Plausible.HTTPClient.Mock,
        :post,
        fn _url, _opts, _params ->
          {:ok, %Finch.Response{body: %{"reports" => []}, status: 200}}
        end
      )

      expect(
        Plausible.HTTPClient.Mock,
        :post,
        fn _url, _opts, _params ->
          {:ok, %Finch.Response{body: %{"reports" => []}, status: 200}}
        end
      )

      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn _url, _opts ->
          body = "fixture/ga4_list_properties.json" |> File.read!() |> Jason.decode!()
          {:ok, %Finch.Response{body: body, status: 200}}
        end
      )

      response =
        conn
        |> post("/#{site.domain}/import/google-analytics/property", %{
          "property" => "properties/428685906",
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777"
        })
        |> html_response(200)

      assert response =~ "No data found. Nothing to import."
    end

    test "redirects to imports and exports on failed property choice with flash error",
         %{
           conn: conn,
           site: site
         } do
      expect(
        Plausible.HTTPClient.Mock,
        :post,
        fn _url, _opts, _params ->
          {:error, %HTTPClient.Non200Error{reason: %{status: 500, body: "Internal server error"}}}
        end
      )

      conn =
        conn
        |> post("/#{site.domain}/import/google-analytics/property", %{
          "property" => "properties/428685906",
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777"
        })

      assert redirected_to(conn, 302) ==
               PlausibleWeb.Router.Helpers.site_path(
                 conn,
                 :settings_imports_exports,
                 site.domain
               )

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "We were unable to retrieve information from Google Analytics"
    end

    test "redirects to imports and exports on rate limiting with flash error",
         %{
           conn: conn,
           site: site
         } do
      expect(
        Plausible.HTTPClient.Mock,
        :post,
        fn _url, _opts, _params ->
          {:error, %HTTPClient.Non200Error{reason: %{status: 429, body: "rate limit exceeded"}}}
        end
      )

      conn =
        conn
        |> post("/#{site.domain}/import/google-analytics/property", %{
          "property" => "properties/428685906",
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777"
        })

      assert redirected_to(conn, 302) ==
               PlausibleWeb.Router.Helpers.site_path(
                 conn,
                 :settings_imports_exports,
                 site.domain
               )

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Google Analytics rate limit has been exceeded. Please try again later."
    end

    test "redirects to imports and exports on expired authentication with flash error",
         %{
           conn: conn,
           site: site
         } do
      expect(
        Plausible.HTTPClient.Mock,
        :post,
        fn _url, _opts, _params ->
          {:error, %HTTPClient.Non200Error{reason: %{status: 403, body: "Access denied"}}}
        end
      )

      conn =
        conn
        |> post("/#{site.domain}/import/google-analytics/property", %{
          "property" => "properties/428685906",
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777"
        })

      assert redirected_to(conn, 302) ==
               PlausibleWeb.Router.Helpers.site_path(
                 conn,
                 :settings_imports_exports,
                 site.domain
               )

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Google Analytics authentication seems to have expired."
    end

    @tag :ce_build_only
    test "redirects to imports and exports on disabled API with flash error", %{
      conn: conn,
      site: site
    } do
      expect(
        Plausible.HTTPClient.Mock,
        :post,
        fn _url, _opts, _params ->
          body = "fixture/ga4_api_disabled_error.json" |> File.read!() |> Jason.decode!()
          {:error, %HTTPClient.Non200Error{reason: %Finch.Response{status: 403, body: body}}}
        end
      )

      conn =
        conn
        |> post("/#{site.domain}/import/google-analytics/property", %{
          "property" => "properties/428685906",
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777"
        })

      assert redirected_to(conn, 302) ==
               PlausibleWeb.Router.Helpers.site_path(
                 conn,
                 :settings_imports_exports,
                 site.domain
               )

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               """
               Google Analytics Admin API has not been used in project 752168887897 before or it is disabled. \
               Enable it by visiting https://console.developers.google.com/apis/api/analyticsadmin.googleapis.com/overview?project=752168887897 then retry. \
               If you enabled this API recently, wait a few minutes for the action to propagate to our systems and retry.\
               """
    end

    test "redirects to imports and exports on timeout with flash error",
         %{
           conn: conn,
           site: site
         } do
      expect(
        Plausible.HTTPClient.Mock,
        :post,
        fn _url, _opts, _params ->
          {:error, %Mint.TransportError{reason: :timeout}}
        end
      )

      conn =
        conn
        |> post("/#{site.domain}/import/google-analytics/property", %{
          "property" => "properties/428685906",
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777"
        })

      assert redirected_to(conn, 302) ==
               PlausibleWeb.Router.Helpers.site_path(
                 conn,
                 :settings_imports_exports,
                 site.domain
               )

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Google Analytics API has timed out."
    end
  end

  describe "GET /:domain/import/google-analytics/confirm" do
    setup [:create_user, :log_in, :create_site]

    test "renders confirmation form for Google Analytics 4 import", %{conn: conn, site: site} do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn _url, _headers ->
          body = "fixture/ga4_get_property.json" |> File.read!() |> Jason.decode!()
          {:ok, %Finch.Response{body: body, status: 200}}
        end
      )

      response =
        conn
        |> get("/#{site.domain}/import/google-analytics/confirm", %{
          "property" => "properties/428685444",
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777",
          "start_date" => "2024-02-22",
          "end_date" => "2024-02-26"
        })
        |> html_response(200)

      action_url = PlausibleWeb.Router.Helpers.google_analytics_path(conn, :import, site.domain)

      assert text_of_attr(response, "form", "action") == action_url

      assert text_of_attr(response, ~s|input[name=access_token]|, "value") == "token"
      assert text_of_attr(response, ~s|input[name=refresh_token]|, "value") == "foo"

      assert text_of_attr(response, ~s|input[name=expires_at]|, "value") ==
               "2022-09-22T20:01:37.112777"

      assert text_of_attr(response, ~s|input[name=property]|, "value") ==
               "properties/428685444"

      assert text_of_attr(response, ~s|input[name=start_date]|, "value") == "2024-02-22"

      assert text_of_attr(response, ~s|input[name=end_date]|, "value") == "2024-02-26"
    end

    test "redirects to imports and exports on failed property retrieval with flash error",
         %{
           conn: conn,
           site: site
         } do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn _url, _params ->
          {:error, %HTTPClient.Non200Error{reason: %{status: 500, body: "Internal server error"}}}
        end
      )

      conn =
        conn
        |> get("/#{site.domain}/import/google-analytics/confirm", %{
          "property" => "properties/428685906",
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777",
          "start_date" => "2024-02-22",
          "end_date" => "2024-02-26"
        })

      assert redirected_to(conn, 302) ==
               PlausibleWeb.Router.Helpers.site_path(
                 conn,
                 :settings_imports_exports,
                 site.domain
               )

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "We were unable to retrieve information from Google Analytics"
    end

    test "redirects to imports and exports on rate limiting with flash error",
         %{
           conn: conn,
           site: site
         } do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn _url, _params ->
          {:error, %HTTPClient.Non200Error{reason: %{status: 429, body: "rate limit exceeded"}}}
        end
      )

      conn =
        conn
        |> get("/#{site.domain}/import/google-analytics/confirm", %{
          "property" => "properties/428685906",
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777",
          "start_date" => "2024-02-22",
          "end_date" => "2024-02-26"
        })

      assert redirected_to(conn, 302) ==
               PlausibleWeb.Router.Helpers.site_path(
                 conn,
                 :settings_imports_exports,
                 site.domain
               )

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Google Analytics rate limit has been exceeded. Please try again later."
    end

    test "redirects to imports and exports on expired authentication with flash error",
         %{
           conn: conn,
           site: site
         } do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn _url, _params ->
          {:error, %HTTPClient.Non200Error{reason: %{status: 403, body: "Access denied"}}}
        end
      )

      conn =
        conn
        |> get("/#{site.domain}/import/google-analytics/confirm", %{
          "property" => "properties/428685906",
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777",
          "start_date" => "2024-02-22",
          "end_date" => "2024-02-26"
        })

      assert redirected_to(conn, 302) ==
               PlausibleWeb.Router.Helpers.site_path(
                 conn,
                 :settings_imports_exports,
                 site.domain
               )

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Google Analytics authentication seems to have expired."
    end

    @tag :ce_build_only
    test "redirects to imports and exports on disabled API with flash error",
         %{
           conn: conn,
           site: site
         } do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn _url, _params ->
          body = "fixture/ga4_api_disabled_error.json" |> File.read!() |> Jason.decode!()
          {:error, %HTTPClient.Non200Error{reason: %{status: 403, body: body}}}
        end
      )

      conn =
        conn
        |> get("/#{site.domain}/import/google-analytics/confirm", %{
          "property" => "properties/428685906",
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777",
          "start_date" => "2024-02-22",
          "end_date" => "2024-02-26"
        })

      assert redirected_to(conn, 302) ==
               PlausibleWeb.Router.Helpers.site_path(
                 conn,
                 :settings_imports_exports,
                 site.domain
               )

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               """
               Google Analytics Admin API has not been used in project 752168887897 before or it is disabled. \
               Enable it by visiting https://console.developers.google.com/apis/api/analyticsadmin.googleapis.com/overview?project=752168887897 then retry. \
               If you enabled this API recently, wait a few minutes for the action to propagate to our systems and retry.\
               """
    end

    test "redirects to imports and exports on timeout with flash error",
         %{
           conn: conn,
           site: site
         } do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn _url, _params ->
          {:error, %Mint.TransportError{reason: :timeout}}
        end
      )

      conn =
        conn
        |> get("/#{site.domain}/import/google-analytics/confirm", %{
          "property" => "properties/428685906",
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777",
          "start_date" => "2024-02-22",
          "end_date" => "2024-02-26"
        })

      assert redirected_to(conn, 302) ==
               PlausibleWeb.Router.Helpers.site_path(
                 conn,
                 :settings_imports_exports,
                 site.domain
               )

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Google Analytics API has timed out."
    end
  end

  describe "POST /:domain/settings/google-import" do
    setup [:create_user, :log_in, :create_site]

    test "creates Google Analytics 4 site import instance", %{conn: conn, site: site} do
      conn =
        post(conn, "/#{site.domain}/settings/google-import", %{
          "property" => "properties/123456",
          "start_date" => "2018-03-01",
          "end_date" => "2022-03-01",
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777"
        })

      assert redirected_to(conn, 302) ==
               PlausibleWeb.Router.Helpers.site_path(conn, :settings_imports_exports, site.domain)

      [site_import] = Plausible.Imported.list_all_imports(site)

      assert site_import.source == :google_analytics_4
      assert site_import.end_date == ~D[2022-03-01]
      assert site_import.status == SiteImport.pending()
    end

    test "schedules a Google Analytics 4 import job in Oban", %{conn: conn, site: site} do
      post(conn, "/#{site.domain}/settings/google-import", %{
        "property" => "properties/123456",
        "start_date" => "2018-03-01",
        "end_date" => "2022-03-01",
        "access_token" => "token",
        "refresh_token" => "foo",
        "expires_at" => "2022-09-22T20:01:37.112777"
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

    test "does not start another import when there's any other in progress for the same site", %{
      conn: conn,
      site: site,
      user: user
    } do
      {:ok, job} =
        Plausible.Imported.NoopImporter.new_import(site, user,
          start_date: ~D[2020-01-02],
          end_date: ~D[2021-10-11]
        )

      post(conn, "/#{site.domain}/settings/google-import", %{
        "property" => "properties/123456",
        "start_date" => "2018-03-01",
        "end_date" => "2022-03-01",
        "access_token" => "token",
        "refresh_token" => "foo",
        "expires_at" => "2022-09-22T20:01:37.112777"
      })

      conn =
        post(conn, "/#{site.domain}/settings/google-import", %{
          "property" => "123456",
          "start_date" => "2018-03-01",
          "end_date" => "2022-03-01",
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777"
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "There's another import still in progress."

      assert [%{id: import_id, legacy: false}] = Plausible.Imported.list_all_imports(site)

      assert job.args.import_id == import_id
    end

    test "redirects to imports and exports with no time window error flash error", %{
      conn: conn,
      site: site
    } do
      start_date = ~D[2022-01-12]
      end_date = ~D[2024-03-13]

      _existing_import =
        insert(:site_import,
          site: site,
          start_date: start_date,
          end_date: end_date,
          status: :completed
        )

      conn =
        post(conn, "/#{site.domain}/settings/google-import", %{
          "property" => "123456",
          "start_date" => "2023-03-01",
          "end_date" => "2022-03-01",
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777"
        })

      assert redirected_to(conn, 302) ==
               PlausibleWeb.Router.Helpers.site_path(
                 conn,
                 :settings_imports_exports,
                 site.domain
               )

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Import failed. No data could be imported because date range overlaps with existing data."
    end
  end
end
