defmodule PlausibleWeb.Live.InstallationV2Test do
  use PlausibleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML
  import Plausible.Teams.Test
  import Mox

  alias Plausible.Site.TrackerScriptConfiguration

  setup [:create_user, :log_in, :create_site]

  setup %{site: site} do
    FunWithFlags.enable(:scriptv2, for_actor: site)
    :ok
  end

  describe "GET /:domain/installationv2" do
    test "static installation screen renders with spinner", %{conn: conn, site: site} do
      resp = get(conn, "/#{site.domain}/installationv2") |> html_response(200)

      assert resp =~ "animate-spin"
    end
  end

  describe "LiveView" do
    test "detects installation type when mounted", %{conn: conn, site: site} do
      stub_dns_lookup_a_records(site.domain)
      stub_detection_wordpress()

      {lv, _} = get_lv(conn, site)

      html = render_async(lv, 500)
      assert text(html) =~ "Verify WordPress installation"
    end

    test "When ?type=wordpress URL parameter is supplied, detected type is unused", %{
      conn: conn,
      site: site
    } do
      stub_dns_lookup_a_records(site.domain)
      stub_detection_manual()

      {lv, _} = get_lv(conn, site, "?type=wordpress")

      html = render_async(lv, 500)
      assert text(html) =~ "Verify WordPress installation"
    end

    test "When ?type=gtm URL parameter is supplied, detected type is unused", %{
      conn: conn,
      site: site
    } do
      stub_dns_lookup_a_records(site.domain)
      stub_detection_wordpress()

      {lv, _} = get_lv(conn, site, "?type=gtm")

      html = render_async(lv, 500)
      assert text(html) =~ "Verify Tag Manager installation"
    end

    test "When ?type=npm URL parameter is supplied, detected type is unused", %{
      conn: conn,
      site: site
    } do
      stub_dns_lookup_a_records(site.domain)
      stub_detection_wordpress()

      {lv, _} = get_lv(conn, site, "?type=npm")

      html = render_async(lv, 500)
      assert text(html) =~ "Verify NPM installation"
    end

    test "When ?type=manual URL parameter is supplied, detected type is unused", %{
      conn: conn,
      site: site
    } do
      stub_dns_lookup_a_records(site.domain)
      stub_detection_wordpress()

      {lv, _} = get_lv(conn, site, "?type=manual")

      html = render_async(lv, 500)
      assert text(html) =~ "Verify Script installation"
    end

    test "allows switching between installation tabs", %{conn: conn, site: site} do
      stub_dns_lookup_a_records(site.domain)
      stub_detection_manual()
      {lv, _html} = get_lv(conn, site, "?type=manual")

      html = render_async(lv, 500)
      assert html =~ "Verify Script installation"

      lv
      |> element("a[href*=\"type=wordpress\"]")
      |> render_click()

      html = render(lv)
      assert html =~ "Verify WordPress installation"

      lv
      |> element("a[href*=\"type=gtm\"]")
      |> render_click()

      html = render(lv)
      assert html =~ "Verify Tag Manager installation"

      lv
      |> element("a[href*=\"type=npm\"]")
      |> render_click()

      html = render(lv)
      assert html =~ "Verify NPM installation"
    end

    test "manual installations has script snippet with expected ID", %{conn: conn, site: site} do
      stub_dns_lookup_a_records(site.domain)
      stub_detection_manual()
      {lv, _html} = get_lv(conn, site, "?type=manual&flow=review")

      assert eventually(fn ->
               html = render(lv)
               {html =~ "Verify Script installation", html}
             end)

      html = render(lv)
      config = Plausible.Repo.get_by!(TrackerScriptConfiguration, site_id: site.id)
      assert html =~ "Privacy-friendly analytics by Plausible"
      assert html =~ "/js/#{config.id}.js"
      assert html =~ "defer=!0"
    end

    test "manual installation shows optional measurements", %{conn: conn, site: site} do
      stub_dns_lookup_a_records(site.domain)
      stub_detection_manual()
      {lv, _html} = get_lv(conn, site, "?type=manual&flow=review")

      html = render_async(lv, 500)
      assert html =~ "Verify Script installation"
      assert html =~ "Optional measurements"
      assert html =~ "Outbound links"
      assert html =~ "File downloads"
      assert html =~ "Form submissions"
    end

    test "manual installation shows advanced options in disclosure", %{conn: conn, site: site} do
      stub_dns_lookup_a_records(site.domain)
      stub_detection_manual()
      {lv, _html} = get_lv(conn, site, "?type=manual&flow=review")

      html = render_async(lv, 500)
      assert html =~ "Verify Script installation"
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
      stub_dns_lookup_a_records(site.domain)
      stub_detection_manual()
      {lv, _html} = get_lv(conn, site, "?type=manual&flow=review")

      html = render_async(lv, 500)
      assert html =~ "Verify Script installation"

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

    for {type, expected_text} <- [
          {"manual", "Verify Script installation"},
          {"wordpress", "Verify WordPress installation"},
          {"gtm", "Verify Tag Manager installation"},
          {"npm", "Verify NPM installation"}
        ] do
      test "submitting form with #{type} redirects to verification", %{conn: conn, site: site} do
        stub_dns_lookup_a_records(site.domain)
        stub_detection_manual()
        {lv, _html} = get_lv(conn, site, "?type=#{unquote(type)}")

        html = render_async(lv, 500)
        assert html =~ unquote(expected_text)

        lv
        |> element("form[phx-submit='submit']")
        |> render_submit(%{
          "tracker_script_configuration" => %{
            "installation_type" => unquote(type),
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
    end

    test "404 goal gets created regardless of user options", %{conn: conn, site: site} do
      stub_dns_lookup_a_records(site.domain)
      stub_detection_manual()
      {lv, _html} = get_lv(conn, site, "?type=manual")

      html = render_async(lv, 500)
      assert html =~ "Verify Script installation"

      # Test with all options disabled
      lv
      |> element("form[phx-submit='submit']")
      |> render_submit(%{
        "tracker_script_configuration" => %{
          "installation_type" => "manual",
          "outbound_links" => "false",
          "file_downloads" => "false",
          "form_submissions" => "false"
        }
      })

      # 404 goal should still be created
      goals = Plausible.Goals.for_site(site)
      assert Enum.any?(goals, &(&1.event_name == "404"))
    end

    test "submitting form with review flow redirects to verification with flow param", %{
      conn: conn,
      site: site
    } do
      stub_dns_lookup_a_records(site.domain)
      stub_detection_manual()
      {lv, _html} = get_lv(conn, site, "?type=manual&flow=review")

      html = render_async(lv, 500)
      assert html =~ "Verify Script installation"

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
      stub_dns_lookup_a_records(site.domain)
      stub_detection_wordpress()

      {lv, _} = get_lv(conn, site)

      html = render_async(lv, 500)
      assert text(html) =~ "We've detected your website is using WordPress"
    end

    test "detected GTM installation shows special message", %{conn: conn, site: site} do
      stub_dns_lookup_a_records(site.domain)
      stub_detection_gtm()

      {lv, _} = get_lv(conn, site)

      html = render_async(lv, 500)
      assert html =~ "Verify Tag Manager installation"
      assert text(html) =~ "We've detected your website is using Google Tag Manager"
    end

    test "detected NPM installation shows npm tab", %{conn: conn, site: site} do
      stub_detection_result(%{
        "v1Detected" => false,
        "gtmLikely" => false,
        "npmLikely" => true,
        "wordpressLikely" => false,
        "wordpressPlugin" => false
      })

      {lv, _} = get_lv(conn, site)

      html = render_async(lv, 500)
      assert html =~ "Verify NPM installation"
    end

    test "shows v1 detection warning for manual installation", %{conn: conn, site: site} do
      stub_dns_lookup_a_records(site.domain)
      stub_detection_manual_with_v1()

      {lv, _} = get_lv(conn, site, "?type=manual")

      html = render_async(lv, 500)
      assert text(html) =~ "Your website is running an outdated version of the tracking script"
    end

    test "does not show v1 detection warning for non-manual installation", %{
      conn: conn,
      site: site
    } do
      stub_dns_lookup_a_records(site.domain)
      stub_detection_wordpress_with_v1()

      {lv, _} = get_lv(conn, site, "?type=wordpress")

      html = render_async(lv, 500)
      assert html =~ "Verify WordPress installation"
      refute text(html) =~ "Your website is running an outdated version of the tracking script"
    end

    test "falls back to manual installation when detection fails at dns check level", %{
      conn: conn,
      site: site
    } do
      stub_dns_lookup_a_records(site.domain, [])

      ExUnit.CaptureLog.capture_log(fn ->
        {lv, _} = get_lv(conn, site)

        assert eventually(fn ->
                 html = render(lv)
                 # Should default to manual installation when detection returns {:error, _}
                 {html =~ "Verify Script installation", html}
               end)
      end)
    end

    test "falls back to manual installation when dns succeeds but detection fails", %{
      conn: conn,
      site: site
    } do
      stub_dns_lookup_a_records(site.domain)
      stub_detection_error()

      ExUnit.CaptureLog.capture_log(fn ->
        {lv, _} = get_lv(conn, site)

        html = render_async(lv, 500)
        # Should default to manual installation when detection returns {:error, _}
        assert html =~ "Verify Script installation"
      end)
    end
  end

  describe "Authorization" do
    test "requires site access permissions", %{conn: conn} do
      other_user = insert(:user)
      other_site = new_site(owner: other_user)

      assert_raise Ecto.NoResultsError, fn ->
        get_lv(conn, other_site)
      end
    end

    test "allows viewer access to installation page", %{conn: conn, user: user} do
      site = new_site()
      add_guest(site, user: user, role: :viewer)
      stub_dns_lookup_a_records(site.domain)
      stub_detection_manual()

      {lv, _} = get_lv(conn, site)

      html = render_async(lv, 500)
      assert html =~ "Verify Script installation"
    end

    test "allows editor access to installation page", %{conn: conn, user: user} do
      site = new_site()
      add_guest(site, user: user, role: :editor)
      stub_dns_lookup_a_records(site.domain)
      stub_detection_manual()

      {lv, _} = get_lv(conn, site)

      html = render_async(lv, 500)
      assert html =~ "Verify Script installation"
    end
  end

  describe "URL Parameter Handling" do
    test "falls back to manual installation when invalid installation type parameter supplied", %{
      conn: conn,
      site: site
    } do
      stub_dns_lookup_a_records(site.domain)
      stub_detection_manual()

      {lv, _} = get_lv(conn, site, "?type=invalid")

      html = render_async(lv, 500)
      assert html =~ "Verify Script installation"
    end

    test "falls back to provisioning flow when invalid flow parameter supplied", %{
      conn: conn,
      site: site
    } do
      stub_dns_lookup_a_records(site.domain)
      stub_detection_manual()

      {lv, _} = get_lv(conn, site, "?flow=invalid")

      html = render_async(lv, 500)
      assert html =~ "Verify Script installation"
    end
  end

  describe "Detection Result Combinations" do
    test "When GTM + Wordpress detected, GTM takes precedence", %{conn: conn, site: site} do
      stub_dns_lookup_a_records(site.domain)

      stub_detection_result(%{
        "v1Detected" => false,
        "gtmLikely" => true,
        "npmLikely" => false,
        "wordpressLikely" => true,
        "wordpressPlugin" => false
      })

      {lv, _} = get_lv(conn, site)

      html = render_async(lv, 500)
      assert html =~ "Verify Tag Manager installation"
    end
  end

  describe "Legacy Installations" do
    test "uses detected type in review flow when installation_type is nil", %{
      conn: conn,
      site: site
    } do
      _config =
        PlausibleWeb.Tracker.get_or_create_tracker_script_configuration!(site, %{
          installation_type: nil,
          outbound_links: true,
          file_downloads: false,
          form_submissions: true
        })

      stub_dns_lookup_a_records(site.domain)
      stub_detection_wordpress()

      {lv, _} = get_lv(conn, site, "?flow=review")

      html = render_async(lv, 500)
      assert html =~ "Verify WordPress installation"
    end
  end

  defp stub_detection_manual do
    stub_detection_result(%{
      "v1Detected" => false,
      "gtmLikely" => false,
      "wordpressLikely" => false,
      "wordpressPlugin" => false
    })
  end

  defp stub_detection_wordpress do
    stub_detection_result(%{
      "v1Detected" => false,
      "gtmLikely" => false,
      "wordpressLikely" => true,
      "wordpressPlugin" => false
    })
  end

  defp stub_detection_gtm do
    stub_detection_result(%{
      "v1Detected" => false,
      "gtmLikely" => true,
      "npmLikely" => false,
      "wordpressLikely" => false,
      "wordpressPlugin" => false
    })
  end

  defp stub_detection_manual_with_v1 do
    stub_detection_result(%{
      "v1Detected" => true,
      "gtmLikely" => false,
      "npmLikely" => false,
      "wordpressLikely" => false,
      "wordpressPlugin" => false
    })
  end

  defp stub_detection_wordpress_with_v1 do
    stub_detection_result(%{
      "v1Detected" => true,
      "gtmLikely" => false,
      "npmLikely" => false,
      "wordpressLikely" => true,
      "wordpressPlugin" => false
    })
  end

  defp stub_detection_result(js_data) do
    Req.Test.stub(:global, fn conn ->
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{"data" => Map.put(js_data, "completed", true)}))
    end)
  end

  defp stub_detection_error do
    Req.Test.stub(:global, fn conn ->
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(
        200,
        Jason.encode!(%{"data" => %{"error" => %{"message" => "Simulated browser error"}}})
      )
    end)
  end

  defp get_lv(conn, site, qs \\ nil) do
    {:ok, lv, html} = live(conn, "/#{site.domain}/installationv2#{qs}")

    {lv, html}
  end

  defp stub_dns_lookup_a_records(domain, a_records \\ [{192, 168, 1, 1}]) do
    lookup_domain = to_charlist(domain)

    Plausible.DnsLookup.Mock
    |> expect(:lookup, fn ^lookup_domain, _type, _record, _opts, _timeout ->
      a_records
    end)
  end
end
