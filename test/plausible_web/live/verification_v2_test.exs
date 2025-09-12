defmodule PlausibleWeb.Live.VerificationTest do
  use PlausibleWeb.ConnCase, async: true

  use Plausible.Test.Support.DNS

  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  @moduletag :capture_log

  setup [:create_user, :log_in, :create_site]

  # @verify_button ~s|button#launch-verification-button[phx-click="launch-verification"]|
  @retry_button ~s|a[phx-click="retry"]|
  # @go_to_dashboard_button ~s|a[href$="?skip_to_dashboard=true"]|
  @progress ~s|#verification-ui p#progress|
  @awaiting ~s|#verification-ui span#awaiting|
  @heading ~s|#verification-ui h2|

  setup %{site: site} do
    FunWithFlags.enable(:scriptv2, for_actor: site)

    :ok
  end

  describe "GET /:domain" do
    @tag :ee_only
    test "static verification screen renders", %{conn: conn, site: site} do
      resp =
        get(conn, conn |> no_slowdown() |> get("/#{site.domain}") |> redirected_to)
        |> html_response(200)

      assert text_of_element(resp, @progress) =~
               "We're visiting your site to ensure that everything is working"

      assert resp =~ "Verifying your installation"
    end

    @tag :ce_build_only
    test "static verification screen renders (ce)", %{conn: conn, site: site} do
      resp =
        get(conn, conn |> no_slowdown() |> get("/#{site.domain}") |> redirected_to)
        |> html_response(200)

      assert resp =~ "Awaiting your first pageview …"
    end
  end

  describe "LiveView" do
    @tag :ee_only
    test "LiveView mounts", %{conn: conn, site: site} do
      stub_lookup_a_records(site.domain)

      stub_verification_result(%{
        "completed" => false,
        "error" => %{"message" => "Error"}
      })

      {_, html} = get_lv(conn, site)

      assert html =~ "Verifying your installation"

      assert text_of_element(html, @progress) =~
               "We're visiting your site to ensure that everything is working"
    end

    @tag :ce_build_only
    test "LiveView mounts (ce)", %{conn: conn, site: site} do
      {_, html} = get_lv(conn, site)
      assert html =~ "Awaiting your first pageview …"
    end

    @tag :ee_only
    test "from custom URL input form to verification", %{conn: conn, site: site} do
      stub_lookup_a_records(site.domain)

      stub_verification_result(%{
        "completed" => false,
        "error" => %{"message" => "Error"}
      })

      # Get liveview with ?custom_url=true query param
      {:ok, lv, html} =
        conn |> no_slowdown() |> live("/#{site.domain}/verification?custom_url=true")

      verifying_installation_text = "Verifying your installation"

      # Assert form is rendered instead of kicking off verification automatically
      assert html =~ "Enter Your Custom URL"
      assert html =~ ~s[value="https://#{site.domain}"]
      assert html =~ ~s[placeholder="https://#{site.domain}"]
      refute html =~ verifying_installation_text

      # Submit custom URL form
      html = lv |> element("form") |> render_submit(%{"custom_url" => "https://abc.de"})

      # Should now show verification progress and hide custom URL form
      assert html =~ verifying_installation_text
      refute html =~ "Enter Your Custom URL"
    end

    @tag :ee_only
    test "eventually verifies installation", %{conn: conn, site: site} do
      stub_lookup_a_records(site.domain)

      stub_verification_result(%{
        "completed" => true,
        "trackerIsInHtml" => true,
        "plausibleIsOnWindow" => true,
        "plausibleIsInitialized" => true,
        "testEvent" => %{
          "normalizedBody" => %{
            "domain" => site.domain
          },
          "responseStatus" => 200
        }
      })

      {:ok, lv} = kick_off_live_verification(conn, site)

      assert eventually(fn ->
               html = render(lv)

               {
                 text_of_element(html, @awaiting) =~
                   "Awaiting your first pageview",
                 html
               }
             end)

      html = render(lv)
      assert html =~ "Success!"
      assert html =~ "Awaiting your first pageview"
    end

    @tag :ee_only
    test "won't await first pageview if site has pageviews", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview)
      ])

      stub_lookup_a_records(site.domain)

      stub_verification_result(%{
        "completed" => true,
        "trackerIsInHtml" => true,
        "plausibleIsOnWindow" => true,
        "plausibleIsInitialized" => true,
        "testEvent" => %{
          "normalizedBody" => %{
            "domain" => site.domain
          },
          "responseStatus" => 200
        }
      })

      {:ok, lv} = kick_off_live_verification(conn, site)

      assert eventually(fn ->
               html = render(lv)

               {
                 text(html) =~ "Success",
                 html
               }
             end)

      html = render(lv)

      refute text_of_element(html, @awaiting) =~ "Awaiting your first pageview"
      refute_redirected(lv, "/#{URI.encode_www_form(site.domain)}/")
    end

    test "will redirect when first pageview arrives", %{conn: conn, site: site} do
      stub_lookup_a_records(site.domain)

      stub_verification_result(%{
        "completed" => true,
        "trackerIsInHtml" => true,
        "plausibleIsOnWindow" => true,
        "plausibleIsInitialized" => true,
        "testEvent" => %{
          "normalizedBody" => %{
            "domain" => site.domain
          },
          "responseStatus" => 200
        }
      })

      {:ok, lv} = kick_off_live_verification(conn, site)

      assert eventually(fn ->
               html = render(lv)

               {
                 text(html) =~ "Awaiting",
                 html
               }
             end)

      populate_stats(site, [
        build(:pageview)
      ])

      assert_redirect(lv, "/#{URI.encode_www_form(site.domain)}/")
    end

    @tag :ce_build_only
    test "will redirect when first pageview arrives (ce)", %{conn: conn, site: site} do
      {:ok, lv} = kick_off_live_verification(conn, site)

      html = render(lv)
      assert text(html) =~ "Awaiting your first pageview …"

      populate_stats(site, [build(:pageview)])

      assert_redirect(lv, "/#{URI.encode_www_form(site.domain)}/")
    end

    for {installation_type_param, expected_text, saved_installation_type} <- [
          {"manual",
           "Please make sure you've copied the snippet to the head of your site, or verify your installation manually.",
           nil},
          {"npm",
           "Please make sure you've initialized Plausible on your site, or verify your installation manually.",
           nil},
          {"gtm",
           "Please make sure you've configured the GTM template correctly, or verify your installation manually.",
           nil},
          {"wordpress",
           "Please make sure you've enabled the plugin, or verify your installation manually.",
           nil},
          # trusts param over saved installation type
          {"wordpress",
           "Please make sure you've enabled the plugin, or verify your installation manually.",
           "npm"},
          # falls back to saved installation type if no param
          {"",
           "Please make sure you've initialized Plausible on your site, or verify your installation manually.",
           "npm"},
          # falls back to manual if no param and no saved installation type
          {"",
           "Please make sure you've copied the snippet to the head of your site, or verify your installation manually.",
           nil}
        ] do
      @tag :ee_only
      test "eventually fails to verify installation (?installation_type=#{installation_type_param}) if saved installation type is #{inspect(saved_installation_type)}",
           %{
             conn: conn,
             site: site
           } do
        stub_lookup_a_records(site.domain)

        stub_verification_result(%{
          "completed" => true,
          "trackerIsInHtml" => false,
          "plausibleIsOnWindow" => false,
          "plausibleIsInitialized" => false
        })

        if unquote(saved_installation_type) do
          PlausibleWeb.Tracker.get_or_create_tracker_script_configuration!(site, %{
            "installation_type" => unquote(saved_installation_type)
          })
        end

        {:ok, lv} =
          kick_off_live_verification(
            conn,
            site,
            "?installation_type=#{unquote(installation_type_param)}"
          )

        assert html =
                 eventually(fn ->
                   html = render(lv)
                   {html =~ "", html}

                   {
                     text_of_element(html, @heading) =~
                       "We couldn't detect Plausible on your site",
                     html
                   }
                 end)

        assert element_exists?(html, @retry_button)

        assert html =~ htmlize_quotes(unquote(expected_text))
        refute element_exists?(html, "#super-admin-report")
      end
    end
  end

  defp get_lv(conn, site, qs \\ nil) do
    {:ok, lv, html} = conn |> no_slowdown() |> live("/#{site.domain}/verification#{qs}")

    {lv, html}
  end

  defp kick_off_live_verification(conn, site, qs \\ nil) do
    {:ok, lv, _html} =
      conn |> no_slowdown() |> no_delay() |> live("/#{site.domain}/verification#{qs}")

    {:ok, lv}
  end

  defp no_slowdown(conn) do
    Plug.Conn.put_private(conn, :slowdown, 0)
  end

  defp no_delay(conn) do
    Plug.Conn.put_private(conn, :delay, 0)
  end

  defp stub_verification_result(js_data) do
    Req.Test.stub(Plausible.InstallationSupport.Checks.InstallationV2, fn conn ->
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{"data" => js_data}))
    end)
  end
end
