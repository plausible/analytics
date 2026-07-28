defmodule PlausibleWeb.Live.InstallationTest do
  use PlausibleWeb.ConnCase
  use Plausible.Test.Support.DNS

  import Phoenix.LiveViewTest

  alias Plausible.Site.TrackerScriptConfiguration

  @migration_guide_link "https://plausible.io/docs/script-update-guide"

  on_ee do
    @submit_button_text "I've installed it"
  else
    @submit_button_text "Proceed to dashboard"
  end

  setup [:create_user, :log_in, :create_site]

  describe "GET /:domain/installation" do
    @tag :ee_only
    test "renders loading installation screen on EE", %{conn: conn, site: site} do
      resp = get(conn, "/#{site.domain}/installation") |> html_response(200)

      assert resp =~ "animate-spin"
    end

    @tag :ce_build_only
    test "no loading spinner, no GTM tab on CE", %{conn: conn, site: site} do
      resp = get(conn, "/#{site.domain}/installation") |> html_response(200)

      tabs_text = text_of_element(resp, "a[data-phx-link='patch']")

      assert length(String.split(tabs_text)) == 3

      assert tabs_text =~ "Script"
      assert tabs_text =~ "WordPress"
      assert tabs_text =~ "NPM"

      refute resp =~ "animate-spin"
    end
  end

  describe "LiveView" do
    @tag :ee_only
    test "detects installation type when mounted", %{conn: conn, site: site} do
      stub_dns()
      stub_detection_wordpress()

      {lv, _} = get_lv(conn, site)

      html = render_async(lv, 500)
      assert text(html) =~ @submit_button_text
    end

    @tag :ee_only
    test "When ?type=wordpress URL parameter is supplied, detected type is unused", %{
      conn: conn,
      site: site
    } do
      stub_dns()
      stub_detection_manual()

      {lv, _} = get_lv(conn, site, "?type=wordpress")

      html = render_async(lv, 500)
      assert text(html) =~ @submit_button_text
    end

    @tag :ee_only
    test "When ?type=gtm URL parameter is supplied, detected type is unused", %{
      conn: conn,
      site: site
    } do
      stub_dns()
      stub_detection_wordpress()

      {lv, _} = get_lv(conn, site, "?type=gtm")

      html = render_async(lv, 500)
      assert text(html) =~ @submit_button_text
    end

    @tag :ee_only
    test "When ?type=npm URL parameter is supplied, detected type is unused", %{
      conn: conn,
      site: site
    } do
      stub_dns()
      stub_detection_wordpress()

      {lv, _} = get_lv(conn, site, "?type=npm")

      html = render_async(lv, 500)
      assert text(html) =~ @submit_button_text
    end

    @tag :ee_only
    test "When ?type=manual URL parameter is supplied, detected type is unused", %{
      conn: conn,
      site: site
    } do
      stub_dns()
      stub_detection_wordpress()

      {lv, _} = get_lv(conn, site, "?type=manual")

      html = render_async(lv, 500)
      assert text(html) =~ @submit_button_text
    end

    on_ee do
      test "allows switching between installation tabs (EE)", %{conn: conn, site: site} do
        stub_dns()
        stub_detection_manual()

        {lv, _html} = get_lv(conn, site, "?type=manual")

        html = render_async(lv, 500)
        assert html =~ htmlize_quotes(@submit_button_text)

        lv
        |> element("a[href*=\"type=wordpress\"]")
        |> render_click()

        html = render(lv)
        assert html =~ htmlize_quotes(@submit_button_text)

        lv
        |> element("a[href*=\"type=gtm\"]")
        |> render_click()

        html = render(lv)
        assert html =~ htmlize_quotes(@submit_button_text)

        lv
        |> element("a[href*=\"type=npm\"]")
        |> render_click()

        html = render(lv)
        assert html =~ htmlize_quotes(@submit_button_text)
      end
    else
      test "allows switching between installation tabs (CE)", %{conn: conn, site: site} do
        {lv, _html} = get_lv(conn, site)

        html = render_async(lv, 500)
        assert html =~ "window.plausible"
        assert html =~ htmlize_quotes(@submit_button_text)

        lv
        |> element("a[href*=\"type=wordpress\"]")
        |> render_click()

        html = render(lv)
        assert html =~ "https://plausible.io/wordpress-analytics-plugin"
        assert html =~ htmlize_quotes(@submit_button_text)

        lv
        |> element("a[href*=\"type=npm\"]")
        |> render_click()

        html = render(lv)
        assert html =~ "@plausible-analytics/tracker"
        assert html =~ htmlize_quotes(@submit_button_text)
      end
    end

    test "manual installations has script snippet with expected ID", %{conn: conn, site: site} do
      on_ee do
        stub_dns()
        stub_detection_manual()
      end

      {lv, _html} = get_lv(conn, site, "?type=manual&flow=review")

      assert eventually(fn ->
               html = render(lv)
               {html =~ htmlize_quotes(@submit_button_text), html}
             end)

      html = render(lv)
      config = Plausible.Repo.get_by!(TrackerScriptConfiguration, site_id: site.id)
      assert html =~ "Privacy-friendly analytics by Plausible"
      assert html =~ "/js/#{config.id}.js"
      assert html =~ "async"
    end

    test "manual installation shows optional measurements", %{conn: conn, site: site} do
      on_ee do
        stub_dns()
        stub_detection_manual()
      end

      {lv, _html} = get_lv(conn, site, "?type=manual&flow=review")

      html = render_async(lv, 500)
      assert html =~ htmlize_quotes(@submit_button_text)
      assert html =~ "Optional measurements"
      assert html =~ "Outbound links"
      assert html =~ "File downloads"
      assert html =~ "Form submissions"
    end

    test "manual installation shows advanced options in disclosure", %{conn: conn, site: site} do
      on_ee do
        stub_dns()
        stub_detection_manual()
      end

      {lv, _html} = get_lv(conn, site, "?type=manual&flow=review")

      html = render_async(lv, 500)
      assert html =~ htmlize_quotes(@submit_button_text)
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
      on_ee do
        stub_dns()
        stub_detection_manual()
      end

      {lv, _html} = get_lv(conn, site, "?type=manual&flow=review")

      html = render_async(lv, 500)
      assert html =~ htmlize_quotes(@submit_button_text)

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

    on_ee do
      for type <- ["manual", "wordpress", "gtm", "npm"] do
        test "submitting form with #{type} redirects to the dashboard with the verification banner (EE)",
             %{
               conn: conn,
               site: site
             } do
          stub_dns()

          stub_detection_manual()
          {lv, _html} = get_lv(conn, site, "?type=#{unquote(type)}")

          html = render_async(lv, 500)
          assert html =~ htmlize_quotes(@submit_button_text)

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
            Routes.stats_path(conn, :stats, site.domain,
              verify_installation: true,
              flow: "provisioning"
            )
          )
        end
      end
    end

    @tag :ce_build_only
    test "submitting the form redirects straight to the dashboard, no banner (CE)", %{
      conn: conn,
      site: site
    } do
      {lv, _html} = get_lv(conn, site)

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

      assert_redirect(lv, Routes.stats_path(conn, :stats, site.domain))
    end

    test "404 goal gets created regardless of user options", %{conn: conn, site: site} do
      on_ee do
        stub_dns()
        stub_detection_manual()
      end

      {lv, _html} = get_lv(conn, site, "?type=manual")

      html = render_async(lv, 500)
      assert html =~ htmlize_quotes(@submit_button_text)

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

    test "submitting form with review flow redirects to the dashboard with the flow param preserved",
         %{
           conn: conn,
           site: site
         } do
      on_ee do
        stub_dns()
        stub_detection_manual()
      end

      {lv, _html} = get_lv(conn, site, "?type=manual&flow=review")

      html = render_async(lv, 500)
      assert html =~ htmlize_quotes(@submit_button_text)

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

      on_ee do
        assert_redirect(
          lv,
          Routes.stats_path(conn, :stats, site.domain,
            verify_installation: true,
            flow: "review"
          )
        )
      end

      on_ce do
        assert_redirect(lv, Routes.stats_path(conn, :stats, site.domain))
      end
    end

    @tag :ee_only
    test "detected WordPress installation preselects WordPress tab", %{conn: conn, site: site} do
      stub_dns()
      stub_detection_wordpress()

      {lv, _} = get_lv(conn, site)

      html = render_async(lv, 500)
      assert text(html) =~ "Install our WordPress plugin"
    end

    @tag :ee_only
    test "if ratelimit for detection is exceeded, does not make detection request and falls back to recommending manual installation",
         %{conn: conn, site: site} do
      stub_dns()

      # exceed the rate limit for site detection
      Plausible.RateLimit.check_rate(
        Plausible.RateLimit,
        "site_detection:#{site.domain}",
        :timer.minutes(60),
        1,
        100
      )

      # this won't be used: if it were used, the output would be different
      stub_detection_wordpress()

      {lv, _} = get_lv(conn, site)

      html = render_async(lv, 500)

      refute text(html) =~ "Install our WordPress plugin"
      assert text(html) =~ @submit_button_text
    end

    @tag :ee_only
    test "detected GTM installation preselects Tag Manager tab", %{conn: conn, site: site} do
      stub_dns()
      stub_detection_gtm()

      {lv, _} = get_lv(conn, site)

      html = render_async(lv, 500)
      assert html =~ htmlize_quotes(@submit_button_text)

      assert text(html) =~ "Install the Plausible template in GTM"
    end

    @tag :ee_only
    test "detected NPM installation shows npm tab", %{conn: conn, site: site} do
      stub_dns()

      stub_detection_result(%{
        "v1Detected" => false,
        "gtmLikely" => false,
        "npm" => true,
        "wordpressLikely" => false,
        "wordpressPlugin" => false
      })

      {lv, _} = get_lv(conn, site)

      html = render_async(lv, 500)
      assert html =~ htmlize_quotes(@submit_button_text)
    end

    @tag :ee_only
    test "shows v1 detection warning and migration guide link for manual installation", %{
      conn: conn,
      site: site
    } do
      stub_dns()
      stub_detection_manual_with_v1()

      {lv, _} = get_lv(conn, site, "?type=manual")

      html = render_async(lv, 500)
      assert text(html) =~ "Your website is running an outdated version of the tracking script"
      assert element_exists?(html, "a[href='#{@migration_guide_link}']")
    end

    @tag :ce_build_only
    test "shows v1 migration guide link for manual instructions", %{conn: conn, site: site} do
      {lv, _} = get_lv(conn, site)

      html = render_async(lv, 500)
      assert text(html) =~ "Still using the legacy snippet"
      assert element_exists?(html, "a[href='#{@migration_guide_link}']")
    end

    test "does not render link to migrate guide on WordPress installation tab", %{
      conn: conn,
      site: site
    } do
      on_ee do
        stub_dns()
        stub_detection_wordpress_with_v1()
      end

      {lv, _} = get_lv(conn, site, "?type=wordpress")

      html = render_async(lv, 500)
      assert html =~ htmlize_quotes(@submit_button_text)
      refute element_exists?(html, "a[href='#{@migration_guide_link}']")
    end

    @tag :ee_only
    test "falls back to manual installation when detection fails at dns check level", %{
      conn: conn,
      site: site
    } do
      expect_dns_unresolvable(site.domain)

      ExUnit.CaptureLog.capture_log(fn ->
        {lv, _} = get_lv(conn, site)

        assert eventually(fn ->
                 html = render(lv)
                 # Should default to manual installation when detection returns {:error, _}
                 {html =~ htmlize_quotes(@submit_button_text), html}
               end)
      end)
    end

    @tag :ee_only
    test "falls back to manual installation when dns succeeds but detection fails", %{
      conn: conn,
      site: site
    } do
      stub_dns()
      stub_detection_error()

      ExUnit.CaptureLog.capture_log(fn ->
        {lv, _} = get_lv(conn, site)

        html = render_async(lv, 500)
        # Should default to manual installation when detection returns {:error, _}
        assert html =~ htmlize_quotes(@submit_button_text)
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

      on_ee do
        stub_dns()
        stub_detection_manual()
      end

      {lv, _} = get_lv(conn, site)

      html = render_async(lv, 500)
      assert html =~ htmlize_quotes(@submit_button_text)
    end

    test "allows editor access to installation page", %{conn: conn, user: user} do
      site = new_site()
      add_guest(site, user: user, role: :editor)

      on_ee do
        stub_dns()
        stub_detection_manual()
      end

      {lv, _} = get_lv(conn, site)

      html = render_async(lv, 500)
      assert html =~ htmlize_quotes(@submit_button_text)
    end
  end

  describe "URL Parameter Handling" do
    test "falls back to manual installation when invalid installation type parameter supplied",
         %{
           conn: conn,
           site: site
         } do
      on_ee do
        stub_dns()
        stub_detection_manual()
      end

      {lv, _} = get_lv(conn, site, "?type=invalid")

      html = render_async(lv, 500)
      assert html =~ htmlize_quotes(@submit_button_text)
    end

    test "falls back to provisioning flow when invalid flow parameter supplied", %{
      conn: conn,
      site: site
    } do
      on_ee do
        stub_dns()
        stub_detection_manual()
      end

      {lv, _} = get_lv(conn, site, "?flow=invalid")

      html = render_async(lv, 500)
      assert html =~ htmlize_quotes(@submit_button_text)
    end
  end

  describe "Detection Result Combinations" do
    @describetag :ee_only

    test "When GTM + Wordpress detected, GTM takes precedence", %{conn: conn, site: site} do
      stub_dns()

      stub_detection_result(%{
        "v1Detected" => false,
        "gtmLikely" => true,
        "wordpressLikely" => true,
        "wordpressPlugin" => false
      })

      {lv, _} = get_lv(conn, site)

      html = render_async(lv, 500)
      assert html =~ htmlize_quotes(@submit_button_text)
    end
  end

  describe "secondary action" do
    @tag :ee_only
    test "offers Skip to /sites in the register flow", %{conn: conn, site: site} do
      stub_dns()
      stub_detection_manual()

      {lv, _} = get_lv(conn, site, "?flow=register")

      html = render_async(lv, 500)

      assert text_of_element(html, ~s|a[href="/sites"]|) == "Skip"
    end

    @tag :ee_only
    test "offers Back to sites in the provisioning flow", %{conn: conn, site: site} do
      stub_dns()
      stub_detection_manual()

      {lv, _} = get_lv(conn, site, "?flow=provisioning")

      html = render_async(lv, 500)

      assert text_of_element(html, ~s|a[href="/sites"]|) == "Back to sites"
    end

    @tag :ee_only
    test "offers Back to settings in the review flow", %{conn: conn, site: site} do
      stub_dns()
      stub_detection_manual()

      {lv, _} = get_lv(conn, site, "?flow=review")

      html = render_async(lv, 500)

      href = Routes.site_path(PlausibleWeb.Endpoint, :settings_general, site.domain)

      assert text_of_element(html, ~s|a[href="#{href}"]|) == "Back to settings"
    end

    @tag :ee_only
    test "offers Back to dashboard, keeping verification on, when return_to=dashboard", %{
      conn: conn,
      site: site
    } do
      stub_dns()
      stub_detection_manual()

      {lv, _} = get_lv(conn, site, "?flow=provisioning&return_to=dashboard")

      html = render_async(lv, 500)

      href =
        Routes.stats_path(PlausibleWeb.Endpoint, :stats, site.domain,
          verify_installation: true,
          flow: "provisioning"
        )

      assert text_of_element(html, ~s|a[href="#{href}"]|) == "Back to dashboard"
    end

    @tag :ee_only
    test "falls back to Skip when the flow is unrecognised", %{conn: conn, site: site} do
      stub_dns()
      stub_detection_manual()

      {lv, _} = get_lv(conn, site, "?flow=")

      html = render_async(lv, 500)

      assert text_of_element(html, ~s|a[href="/sites"]|) == "Skip"
    end
  end

  describe "Legacy Installations" do
    @tag :ee_only
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

      stub_dns()
      stub_detection_wordpress()

      {lv, _} = get_lv(conn, site, "?flow=review")

      html = render_async(lv, 500)
      assert html =~ htmlize_quotes(@submit_button_text)
    end
  end

  defp stub_detection_manual do
    stub_detection_result(%{
      "v1Detected" => false,
      "gtmLikely" => false,
      "npm" => false,
      "wordpressLikely" => false,
      "wordpressPlugin" => false
    })
  end

  defp stub_detection_wordpress do
    stub_detection_result(%{
      "v1Detected" => false,
      "gtmLikely" => false,
      "npm" => false,
      "wordpressLikely" => true,
      "wordpressPlugin" => false
    })
  end

  defp stub_detection_gtm do
    stub_detection_result(%{
      "v1Detected" => false,
      "gtmLikely" => true,
      "npm" => false,
      "wordpressLikely" => false,
      "wordpressPlugin" => false
    })
  end

  defp stub_detection_manual_with_v1 do
    stub_detection_result(%{
      "v1Detected" => true,
      "gtmLikely" => false,
      "npm" => false,
      "wordpressLikely" => false,
      "wordpressPlugin" => false
    })
  end

  on_ee do
    defp stub_detection_wordpress_with_v1 do
      stub_detection_result(%{
        "v1Detected" => true,
        "gtmLikely" => false,
        "npm" => false,
        "wordpressLikely" => true,
        "wordpressPlugin" => false
      })
    end
  end

  defp stub_detection_result(js_data) do
    Req.Test.stub(Plausible.InstallationSupport.Checks.Detection, fn conn ->
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{"data" => Map.put(js_data, "completed", true)}))
    end)
  end

  defp stub_detection_error do
    Req.Test.stub(Plausible.InstallationSupport.Checks.Detection, fn conn ->
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(
        200,
        Jason.encode!(%{"data" => %{"error" => %{"message" => "Simulated browser error"}}})
      )
    end)
  end

  defp get_lv(conn, site, qs \\ nil) do
    {:ok, lv, html} = live(conn, "/#{site.domain}/installation#{qs}")

    {lv, html}
  end
end
