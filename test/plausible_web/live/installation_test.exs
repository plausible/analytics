defmodule PlausibleWeb.Live.InstallationTest do
  use PlausibleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  setup [:create_user, :log_in, :create_site]

  describe "GET /:domain" do
    test "static verification screen renders", %{conn: conn, site: site} do
      resp = get(conn, "/#{site.domain}/installation") |> html_response(200)

      assert resp =~ "Determining installation type"
      refute resp =~ "Review your existing installation."
    end

    test "static verification screen renders for flow=review", %{conn: conn, site: site} do
      resp =
        conn
        |> get("/#{site.domain}/installation?flow=review&installation_type=manual")
        |> html_response(200)

      assert resp =~ "Review your existing installation."
      assert resp =~ "Verify your installation"

      assert resp =~
               Routes.site_path(PlausibleWeb.Endpoint, :verification, site.domain, flow: "review")
    end

    test "static verification screen renders for flow=domain_change", %{conn: conn, site: site} do
      resp =
        conn
        |> get("/#{site.domain}/installation?flow=domain_change&installation_type=manual")
        |> html_response(200)

      assert resp =~ "Your domain has been changed"
      assert resp =~ "I understand, I'll update my website"
      refute resp =~ "Review your existing installation."

      assert resp =~
               Routes.site_path(PlausibleWeb.Endpoint, :verification, site.domain,
                 flow: "domain_change"
               )
    end

    test "renders pre-determined installation type: WordPress", %{conn: conn, site: site} do
      resp =
        conn
        |> get("/#{site.domain}/installation?installation_type=WordPress")
        |> html_response(200)

      assert resp =~ "Install WordPress plugin"
      assert resp =~ "Start collecting data"
      refute resp =~ "Review your existing installation."

      assert resp =~
               Routes.site_path(PlausibleWeb.Endpoint, :verification, site.domain,
                 installation_type: "WordPress"
               )
    end

    test "renders pre-determined installation type: GTM", %{conn: conn, site: site} do
      resp =
        conn |> get("/#{site.domain}/installation?installation_type=GTM") |> html_response(200)

      assert resp =~ "Install Google Tag Manager"
      assert resp =~ "Start collecting data"
      refute resp =~ "Review your existing installation."

      assert resp =~
               Routes.site_path(PlausibleWeb.Endpoint, :verification, site.domain,
                 installation_type: "GTM"
               )
    end

    test "renders pre-determined installation type: manual", %{conn: conn, site: site} do
      resp =
        conn |> get("/#{site.domain}/installation?installation_type=manual") |> html_response(200)

      assert resp =~ "Manual installation"
      assert resp =~ "Start collecting data"
      refute resp =~ "Review your existing installation."

      assert resp =~
               Routes.site_path(PlausibleWeb.Endpoint, :verification, site.domain,
                 installation_type: "manual"
               )
    end

    test "ignores unknown installation types", %{conn: conn, site: site} do
      resp =
        conn |> get("/#{site.domain}/installation?installation_type=UM_NO") |> html_response(200)

      assert resp =~ "Determining installation type"
    end
  end

  describe "LiveView" do
    test "mounts and detects installation type", %{conn: conn, site: site} do
      stub_fetch_body(200, "wp-content")

      {lv, _} = get_lv(conn, site)

      assert eventually(fn ->
               html = render(lv)

               {
                 text(html) =~ "Install WordPress",
                 html
               }
             end)

      _ = render(lv)
    end

    @tag :slow
    test "mounts and does not detect installation type, if it's provided", %{
      conn: conn,
      site: site
    } do
      stub_fetch_body(200, "wp-content")

      {lv, _} = get_lv(conn, site, "?installation_type=GTM")

      refute eventually(fn ->
               html = render(lv)

               {
                 text(html) =~ "Install WordPress",
                 html
               }
             end)

      _ = render(lv)
    end

    test "allows manual snippet customization", %{conn: conn, site: site} do
      {lv, html} = get_lv(conn, site, "?installation_type=manual")

      assert text_of_element(html, "textarea#snippet") ==
               "&amp;lt;script defer data-domain=&amp;quot;#{site.domain}&amp;quot; src=&amp;quot;http://localhost:8000/js/script.js&amp;quot;&amp;gt;&amp;lt;/script&amp;gt;"

      for param <- PlausibleWeb.Live.Installation.script_config_params() do
        lv
        |> element(~s|form#snippet-form|)
        |> render_change(%{
          param => "on"
        })

        html = lv |> render()
        assert text_of_element(html, "textarea#snippet") =~ "/js/script.#{param}.js"

        lv
        |> element(~s|form#snippet-form|)
        |> render_change(%{})

        html = lv |> render()
        assert text_of_element(html, "textarea#snippet") =~ "/js/script.js"
      end
    end

    test "allows GTM snippet customization", %{conn: conn, site: site} do
      {lv, html} = get_lv(conn, site, "?installation_type=GTM")

      assert text_of_element(html, "textarea#snippet") =~ "script.defer = true"

      for param <- PlausibleWeb.Live.Installation.script_config_params() do
        lv
        |> element(~s|form#snippet-form|)
        |> render_change(%{
          param => "on"
        })

        html = lv |> render()
        assert text_of_element(html, "textarea#snippet") =~ "/js/script.#{param}.js"

        lv
        |> element(~s|form#snippet-form|)
        |> render_change(%{})

        html = lv |> render()
        assert text_of_element(html, "textarea#snippet") =~ "/js/script.js"
      end
    end

    test "turning on file-downloads and outbound-links creates special goals", %{
      conn: conn,
      site: site
    } do
      {lv, _html} = get_lv(conn, site, "?installation_type=manual")

      assert Plausible.Goals.for_site(site) == []

      lv
      |> element(~s|form#snippet-form|)
      |> render_change(%{
        "file-downloads" => "on",
        "outbound-links" => "on"
      })

      lv |> render()

      assert [clicks, downloads] = Plausible.Goals.for_site(site)
      assert clicks.event_name == "Outbound Link: Click"
      assert downloads.event_name == "File Download"
    end

    test "turning off file-downloads and outbound-links deletes special goals", %{
      conn: conn,
      site: site
    } do
      {lv, _html} = get_lv(conn, site, "?installation_type=manual")

      assert Plausible.Goals.for_site(site) == []

      lv
      |> element(~s|form#snippet-form|)
      |> render_change(%{
        "file-downloads" => "on",
        "outbound-links" => "on"
      })

      lv
      |> element(~s|form#snippet-form|)
      |> render_change(%{})

      assert [] = Plausible.Goals.for_site(site)
    end
  end

  defp stub_fetch_body(f) when is_function(f, 1) do
    Req.Test.stub(Plausible.Verification.Checks.FetchBody, f)
  end

  defp stub_fetch_body(status, body) do
    stub_fetch_body(fn conn ->
      conn
      |> put_resp_content_type("text/html")
      |> send_resp(status, body)
    end)
  end

  defp get_lv(conn, site, qs \\ nil) do
    {:ok, lv, html} = live(conn, "/#{site.domain}/installation#{qs}")

    {lv, html}
  end
end
