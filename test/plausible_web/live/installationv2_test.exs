defmodule PlausibleWeb.Live.InstallationV2Test do
  use PlausibleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  alias Plausible.Site.TrackerScriptConfiguration

  setup [:create_user, :log_in, :create_site]

  setup %{site: site} do
    FunWithFlags.enable(:scriptv2, for_actor: site)
    :ok
  end

  describe "GET /:domain/installationv2" do
    test "static installation screen renders", %{conn: conn, site: site} do
      resp = get(conn, "/#{site.domain}/installationv2") |> html_response(200)

      assert resp =~ "Script"
      assert resp =~ "WordPress"
      assert resp =~ "Tag Manager"
      assert resp =~ "NPM"
    end

    test "static installation screen renders for flow=review", %{conn: conn, site: site} do
      resp =
        conn
        |> get("/#{site.domain}/installationv2?flow=review")
        |> html_response(200)

      assert resp =~ "Verify your installation"
    end

    test "renders pre-determined installation type: manual", %{conn: conn, site: site} do
      resp =
        conn |> get("/#{site.domain}/installationv2?type=manual") |> html_response(200)

      assert resp =~ "Script installation"
    end

    test "renders pre-determined installation type: WordPress", %{conn: conn, site: site} do
      resp =
        conn
        |> get("/#{site.domain}/installationv2?type=wordpress")
        |> html_response(200)

      assert resp =~ "WordPress installation"
    end

    test "renders pre-determined installation type: GTM", %{conn: conn, site: site} do
      resp =
        conn |> get("/#{site.domain}/installationv2?type=gtm") |> html_response(200)

      assert resp =~ "Tag Manager installation"
    end

    test "renders pre-determined installation type: NPM", %{conn: conn, site: site} do
      resp =
        conn |> get("/#{site.domain}/installationv2?type=npm") |> html_response(200)

      assert resp =~ "NPM installation"
    end
  end

  describe "LiveView" do
    test "detects installation type when mounted", %{conn: conn, site: site} do
      stub_fetch_body(200, "wp-content")

      {lv, _} = get_lv(conn, site)

      assert eventually(fn ->
               html = render(lv)

               {
                 text(html) =~ "WordPress installation",
                 html
               }
             end)

      _ = render(lv)
    end

    test "When ?type URL parameter is supplied, detected type is unused", %{
      conn: conn,
      site: site
    } do
      stub_fetch_body(200, "wp-content")

      {lv, _} = get_lv(conn, site, "?type=gtm")

      assert eventually(fn ->
               html = render(lv)

               {
                 text(html) =~ "Tag Manager installation",
                 html
               }
             end)

      _ = render(lv)
    end

    test "allows switching between installation tabs", %{conn: conn, site: site} do
      {lv, _html} = get_lv(conn, site, "?type=manual")

      assert eventually(fn ->
               html = render(lv)
               {html =~ "Script installation", html}
             end)

      lv
      |> element("a[href*=\"type=wordpress\"]")
      |> render_click()

      html = render(lv)
      assert html =~ "WordPress installation"

      lv
      |> element("a[href*=\"type=gtm\"]")
      |> render_click()

      html = render(lv)
      assert html =~ "Tag Manager installation"

      lv
      |> element("a[href*=\"type=npm\"]")
      |> render_click()

      html = render(lv)
      assert html =~ "NPM installation"
    end

    test "manual installation shows optional measurements", %{conn: conn, site: site} do
      {lv, _html} = get_lv(conn, site, "?type=manual&flow=review")

      assert eventually(fn ->
               html = render(lv)
               {html =~ "Script installation", html}
             end)

      html = render(lv)
      assert html =~ "Optional measurements"
      assert html =~ "Outbound links"
      assert html =~ "File downloads"
      assert html =~ "Form submissions"
    end

    test "manual installation shows advanced options in disclosure", %{conn: conn, site: site} do
      {lv, _html} = get_lv(conn, site, "?type=manual&flow=review")

      assert eventually(fn ->
               html = render(lv)
               {html =~ "Script installation", html}
             end)

      html = render(lv)
      assert html =~ "Advanced options"

      assert html =~ "Manual tagging"
      assert html =~ "404 error pages"
      assert html =~ "Hashed page paths"
      assert html =~ "Custom properties"
      assert html =~ "Ecommerce revenue"
    end

    test "toggling optional measurements updates tracker configuration", %{
      conn: conn,
      site: site
    } do
      {lv, _html} = get_lv(conn, site, "?type=manual&flow=review")

      assert eventually(fn ->
               html = render(lv)
               {html =~ "Script installation", html}
             end)

      config = TrackerScriptConfiguration |> Plausible.Repo.get_by!(site_id: site.id)
      assert config.outbound_links == true
      assert config.file_downloads == true
      assert config.form_submissions == true

      lv
      |> element("form[phx-submit='submit']")
      |> render_submit(%{
        "tracker_script_configuration" => %{
          "installation_type" => "manual",
          "outbound_links" => "false",
          "file_downloads" => "true",
          "form_submissions" => "true"
        }
      })

      updated_config = TrackerScriptConfiguration |> Plausible.Repo.get_by!(site_id: site.id)
      assert updated_config.outbound_links == false
      assert updated_config.file_downloads == true
      assert updated_config.form_submissions == true
    end

    test "submitting form redirects to verification", %{conn: conn, site: site} do
      {lv, _html} = get_lv(conn, site, "?type=manual")

      assert eventually(fn ->
               html = render(lv)
               {html =~ "Start collecting data", html}
             end)

      lv
      |> element("form[phx-submit='submit']")
      |> render_submit(%{
        "tracker_script_configuration" => %{
          "installation_type" => "manual",
          "outbound_links" => "true",
          "file_downloads" => "true",
          "form_submissions" => "true"
        }
      })

      assert_redirect(
        lv,
        Routes.site_path(conn, :verification, site.domain, flow: "provisioning")
      )
    end

    test "submitting form with review flow redirects to verification with flow param", %{
      conn: conn,
      site: site
    } do
      {lv, _html} = get_lv(conn, site, "?type=manual&flow=review")

      lv
      |> element("form[phx-submit='submit']")
      |> render_submit(%{
        "tracker_script_configuration" => %{
          "installation_type" => "manual",
          "outbound_links" => "true",
          "file_downloads" => "true",
          "form_submissions" => "true"
        }
      })

      assert_redirect(lv, Routes.site_path(conn, :verification, site.domain, flow: "review"))
    end

    test "detected WordPress installation shows special message", %{conn: conn, site: site} do
      stub_fetch_body(200, "wp-content")

      {lv, _} = get_lv(conn, site)

      assert eventually(fn ->
               html = render(lv)

               {
                 text(html) =~ "We've detected your website is using WordPress",
                 html
               }
             end)
    end

    test "detected GTM installation shows special message", %{conn: conn, site: site} do
      stub_fetch_body(200, "googletagmanager.com/gtm.js")

      {lv, _} = get_lv(conn, site)

      assert eventually(fn ->
               html = render(lv)
               {html =~ "Tag Manager installation", html}
             end)

      assert eventually(fn ->
               html = render(lv)

               {
                 text(html) =~ "We've detected your website is using Google Tag Manager",
                 html
               }
             end)
    end
  end

  defp stub_fetch_body(f) when is_function(f, 1) do
    Req.Test.stub(Plausible.InstallationSupport.Checks.FetchBody, f)
  end

  defp stub_fetch_body(status, body) do
    stub_fetch_body(fn conn ->
      conn
      |> put_resp_content_type("text/html")
      |> send_resp(status, body)
    end)
  end

  defp get_lv(conn, site, qs \\ nil) do
    {:ok, lv, html} = live(conn, "/#{site.domain}/installationv2#{qs}")

    {lv, html}
  end
end
