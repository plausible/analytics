defmodule PlausibleWeb.Live.VerificationTest do
  use PlausibleWeb.ConnCase

  use Plausible.Test.Support.DNS

  import Phoenix.LiveViewTest

  @moduletag :capture_log

  setup [:create_user, :log_in, :create_site]

  @retry_button ~s|a[phx-click="retry"]|
  @progress ~s|#verification-ui p#progress|
  @heading ~s|#verification-ui h3|
  @banner ~s|#verification-ui|

  @in_progress_text "Verifying your installation"

  describe "GET /:domain" do
    @tag :ee_only
    test "static verification banner renders on a freshly provisioned site", %{
      conn: conn,
      site: site
    } do
      resp =
        conn
        |> no_slowdown()
        |> get("/#{site.domain}?verify_installation=true")
        |> html_response(200)

      assert text_of_element(resp, @progress) =~
               "We're visiting your site to ensure that everything is working"

      assert resp =~ @in_progress_text
    end

    @tag :ce_build_only
    test "no verification banner renders on CE", %{conn: conn, site: site} do
      resp = get(conn, "/#{site.domain}") |> html_response(200)

      refute resp =~ "verification-ui"
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

      assert html =~ @in_progress_text

      assert text_of_element(html, @progress) =~
               "We're visiting your site to ensure that everything is working"
    end

    @tag :ee_only
    test "clicking the custom URL link reveals an inline form next to the retry button, submitting kicks off a new run",
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

      {:ok, lv} = kick_off_live_verification(conn, site)

      assert eventually(fn ->
               html = render(lv)

               {
                 text_of_element(html, @heading) =~ "We couldn't detect Plausible on your site",
                 html
               }
             end)

      html = lv |> render_click("show-custom-url-form")

      refute html =~ @in_progress_text

      refute element_exists?(html, @retry_button)
      refute element_exists?(html, "#verify-custom-url-link")

      assert element_exists?(
               html,
               ~s|form[phx-submit="verify-custom-url"] input[name="custom_url"]|
             )

      assert html =~ ~s[value="https://#{site.domain}"]
      assert html =~ ~s[placeholder="https://#{site.domain}"]

      lv
      |> element("form[phx-submit='verify-custom-url']")
      |> render_submit(%{"custom_url" => "https://abc.de"})

      assert eventually(fn ->
               html = render(lv)
               {html =~ @in_progress_text, html}
             end)
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
               {html =~ "Tracking is active on your site", html}
             end)
    end

    @tag :ee_only
    test "the dismissed flag keeps the banner hidden even if a late update arrives while still connected",
         %{conn: conn, site: site} do
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

      html = render(lv)
      assert html =~ @in_progress_text
      refute class_of_element(html, @banner) =~ "hidden"

      html = render_click(lv, "dismiss")
      assert class_of_element(html, @banner) =~ "hidden"

      # This might look a bit counter-intuitive -- dismissing the banner
      # closes the websocket connection and the LV process would normally
      # die before the component gets notified of success.

      # However, `Phoenix.LiveViewTest` can't simulate a real socket closing,
      # so the process here just stays alive regardless. What this guards is
      # the defensive `dismissed?` gate itself: if this process is ever still
      # around when a late update arrives, for whatever reason, the banner
      # must stay hidden.
      assert eventually(fn ->
               html = render(lv)
               {html =~ "Tracking is active on your site", html}
             end)

      html = render(lv)
      assert class_of_element(html, @banner) =~ "hidden"
    end

    @tag :ee_only
    test "dismissing tells the client to close the websocket connection",
         %{conn: conn, site: site} do
      stub_lookup_a_records(site.domain)

      stub_verification_result(%{
        "completed" => false,
        "error" => %{"message" => "Error"}
      })

      {:ok, lv} = kick_off_live_verification(conn, site)

      render_click(lv, "dismiss")

      assert_push_event(lv, "disconnect-liveview", %{})
    end

    for {expected_text, saved_installation_type} <- [
          {"Make sure you've copied the snippet to the head of your site, or verify your installation manually.",
           "manual"},
          {"Make sure you've initialized Plausible on your site, or verify your installation manually.",
           "npm"},
          {"Make sure you've configured the GTM template correctly, or verify your installation manually.",
           "gtm"},
          {"Make sure you've enabled the WordPress plugin, or verify your installation manually.",
           "wordpress"},
          # falls back to manual when there's no saved installation type
          {"Make sure you've copied the snippet to the head of your site, or verify your installation manually.",
           nil}
        ] do
      @tag :ee_only
      test "eventually fails to verify installation if saved installation type is #{inspect(saved_installation_type)}",
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

        {:ok, lv} = kick_off_live_verification(conn, site)

        html =
          eventually(fn ->
            html = render(lv)

            {
              text_of_element(html, @heading) =~ "We couldn't detect Plausible on your site",
              html
            }
          end)

        assert element_exists?(html, @retry_button)

        assert text_of_element(html, "#recommendation") =~ unquote(expected_text)
        refute element_exists?(html, "#super-admin-report")
      end
    end
  end

  defp get_lv(conn, site) do
    {:ok, lv, html} =
      conn |> no_slowdown() |> as_live() |> live(verification_path(site))

    {lv, html}
  end

  defp kick_off_live_verification(conn, site) do
    {:ok, lv, _html} =
      conn |> no_slowdown() |> no_delay() |> as_live() |> live(verification_path(site))

    {:ok, lv}
  end

  # `PlausibleWeb.Live.Verification` is rendered via `live_render/3` from a
  # plain controller-rendered page rather than a live router route, so it
  # never carries the `:live_module` assign `Phoenix.LiveViewTest.live/2`
  # looks for. Mirrors the same workaround used in other live_render-embedded
  # LiveView tests (e.g. props_settings_test.exs).
  defp as_live(conn), do: assign(conn, :live_module, PlausibleWeb.Live.Verification)

  defp verification_path(site), do: "/#{site.domain}?verify_installation=true"

  defp no_slowdown(conn) do
    Plug.Conn.put_private(conn, :slowdown, 0)
  end

  defp no_delay(conn) do
    Plug.Conn.put_private(conn, :delay, 0)
  end

  defp stub_verification_result(js_data) do
    Req.Test.stub(Plausible.InstallationSupport.Checks.VerifyInstallation, fn conn ->
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{"data" => js_data}))
    end)
  end
end
