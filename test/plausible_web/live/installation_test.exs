defmodule PlausibleWeb.Live.InstallationTest do
  use PlausibleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  setup [:create_user, :log_in, :create_site]

  describe "GET /:domain/installation" do
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
               Routes.site_path(PlausibleWeb.Endpoint, :verification, site.domain,
                 flow: PlausibleWeb.Flows.review()
               )
    end

    test "static verification screen renders for flow=domain_change", %{conn: conn, site: site} do
      resp =
        conn
        |> get("/#{site.domain}/installation?flow=#{PlausibleWeb.Flows.domain_change()}")
        |> html_response(200)

      assert resp =~ "Your domain has been changed"
      assert resp =~ "I understand, I'll update my website"
      assert resp =~ "Manual installation"
      refute resp =~ "Review your existing installation."

      assert resp =~
               Routes.site_path(PlausibleWeb.Endpoint, :verification, site.domain,
                 flow: PlausibleWeb.Flows.domain_change()
               )
    end

    test "static verification screen renders for flow=domain_change using original installation type",
         %{conn: conn, site: site} do
      site = Plausible.Sites.update_installation_meta!(site, %{installation_type: "WordPress"})

      resp =
        conn
        |> get("/#{site.domain}/installation?flow=#{PlausibleWeb.Flows.domain_change()}")
        |> html_response(200)

      assert resp =~ "Your domain has been changed"
      assert resp =~ "I understand, I'll update my website"
      assert resp =~ "WordPress plugin"
      refute resp =~ "Manuial installation"
      refute resp =~ "Review your existing installation."

      assert resp =~
               Routes.site_path(PlausibleWeb.Endpoint, :verification, site.domain,
                 flow: PlausibleWeb.Flows.domain_change()
               )
    end

    test "renders pre-determined installation type: WordPress", %{conn: conn, site: site} do
      resp =
        conn
        |> get("/#{site.domain}/installation?installation_type=wordpress")
        |> html_response(200)

      assert resp =~ "Install WordPress plugin"
      assert resp =~ "Start collecting data"
      refute resp =~ "Review your existing installation."

      assert resp =~
               Routes.site_path(PlausibleWeb.Endpoint, :verification, site.domain,
                 installation_type: "wordpress"
               )
    end

    test "renders pre-determined installation type: GTM", %{conn: conn, site: site} do
      resp =
        conn |> get("/#{site.domain}/installation?installation_type=gtm") |> html_response(200)

      assert resp =~ "Install Google Tag Manager"
      assert resp =~ "Start collecting data"
      refute resp =~ "Review your existing installation."

      assert resp =~
               Routes.site_path(PlausibleWeb.Endpoint, :verification, site.domain,
                 installation_type: "gtm"
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

      {lv, _} = get_lv(conn, site, "?installation_type=gtm")

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

      for {param, script_extension} <- PlausibleWeb.Live.Installation.script_extension_params() do
        lv
        |> element(~s|form#snippet-form|)
        |> render_change(%{
          param => "on"
        })

        html = lv |> render()
        assert text_of_element(html, "textarea#snippet") =~ "/js/script.#{script_extension}.js"

        lv
        |> element(~s|form#snippet-form|)
        |> render_change(%{})

        html = lv |> render()
        assert text_of_element(html, "textarea#snippet") =~ "/js/script.js"

        assert html =~ "Snippet updated"
      end
    end

    test "allows GTM snippet customization", %{conn: conn, site: site} do
      {lv, html} = get_lv(conn, site, "?installation_type=gtm")

      assert text_of_element(html, "textarea#snippet") =~ "script.defer = true"

      for {param, script_extension} <- PlausibleWeb.Live.Installation.script_extension_params() do
        lv
        |> element(~s|form#snippet-form|)
        |> render_change(%{
          param => "on"
        })

        html = lv |> render()
        assert text_of_element(html, "textarea#snippet") =~ "/js/script.#{script_extension}.js"

        lv
        |> element(~s|form#snippet-form|)
        |> render_change(%{})

        html = lv |> render()
        assert text_of_element(html, "textarea#snippet") =~ "/js/script.js"

        assert html =~ "Snippet updated"
      end
    end

    test "allows manual snippet customization with 404 links", %{conn: conn, site: site} do
      {lv, _html} = get_lv(conn, site, "?installation_type=manual")

      lv
      |> element(~s|form#snippet-form|)
      |> render_change(%{
        "track_404_pages" => "on"
      })

      html = lv |> render()

      assert text_of_element(html, "textarea#snippet") =~
               "function() { (window.plausible.q = window.plausible.q || []).push(arguments) }&amp;lt;/script&amp;gt;"

      lv
      |> element(~s|form#snippet-form|)
      |> render_change(%{})

      html = lv |> render()

      refute text_of_element(html, "textarea#snippet") =~
               "function() { (window.plausible.q = window.plausible.q || []).push(arguments) }&amp;lt;/script&amp;gt;"
    end

    test "turning on file-downloads, outbound-links and 404 creates special goals", %{
      conn: conn,
      site: site
    } do
      {lv, _html} = get_lv(conn, site, "?installation_type=manual")

      assert Plausible.Goals.for_site(site) == []

      lv
      |> element(~s|form#snippet-form|)
      |> render_change(%{
        "file_downloads" => "on",
        "outbound_links" => "on",
        "track_404_pages" => "on"
      })

      lv |> render()

      assert [track_404_pages, downloads, clicks] =
               Plausible.Goals.for_site(site) |> Enum.sort_by(& &1.event_name)

      assert track_404_pages.event_name == "404"
      assert downloads.event_name == "File Download"
      assert clicks.event_name == "Outbound Link: Click"
    end

    test "turning off file-downloads, outbound-links and 404 deletes special goals", %{
      conn: conn,
      site: site
    } do
      {lv, _html} = get_lv(conn, site, "?installation_type=manual")

      assert Plausible.Goals.for_site(site) == []

      lv
      |> element(~s|form#snippet-form|)
      |> render_change(%{
        "file_downloads" => "on",
        "outbound_links" => "on",
        "track_404_pages" => "on"
      })

      assert [_, _, _] = Plausible.Goals.for_site(site)

      lv
      |> element(~s|form#snippet-form|)
      |> render_change(%{
        "file_downloads" => "on",
        "outbound_links" => "on"
      })

      assert render(lv) =~ "Snippet updated and goal deleted"

      lv
      |> element(~s|form#snippet-form|)
      |> render_change(%{
        "file_downloads" => "on"
      })

      assert render(lv) =~ "Snippet updated and goal deleted"

      lv
      |> element(~s|form#snippet-form|)
      |> render_change(%{})

      assert render(lv) =~ "Snippet updated and goal deleted"

      assert [] = Plausible.Goals.for_site(site)
    end

    test "turning off remaining checkboxes doesn't render goal deleted flash", %{
      conn: conn,
      site: site
    } do
      {lv, _html} = get_lv(conn, site, "?installation_type=manual")

      lv
      |> element(~s|form#snippet-form|)
      |> render_change(%{
        "tagged_events" => "on",
        "hash_based_routing" => "on",
        "pageview_props" => "on",
        "revenue_tracking" => "on"
      })

      assert render(lv) =~ "Snippet updated. Please insert the newest snippet into your site"

      lv
      |> element(~s|form#snippet-form|)
      |> render_change(%{})

      assert render(lv) =~ "Snippet updated. Please insert the newest snippet into your site"
    end

    test "no changes", %{conn: conn, site: site} do
      {lv, _html} = get_lv(conn, site, "?installation_type=manual")

      lv
      |> element(~s|form#snippet-form|)
      |> render_change(%{})

      lv
      |> element(~s|form#snippet-form|)
      |> render_change(%{})

      refute render(lv) =~ "Snippet updated"
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
