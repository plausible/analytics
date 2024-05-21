defmodule PlausibleWeb.Live.VerificationTest do
  use PlausibleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  setup [:create_user, :log_in, :create_site]

  @verify_button ~s|button#launch-verification-button[phx-click="launch-verification"]|
  @verification_modal ~s|div#verification-modal|
  @retry_button ~s|a[phx-click="retry"]|
  @go_to_dashboard_button ~s|a[href$="?skip_to_dashboard=true"]|
  @progress ~s|div#progress|

  describe "GET /:domain" do
    test "static verification screen renders", %{conn: conn, site: site} do
      resp = conn |> no_slowdown() |> get("/#{site.domain}") |> html_response(200)

      assert text_of_element(resp, @progress) =~
               "We're visiting your site to ensure that everything is working correctly"

      assert resp =~ "Verifying your integration"
      assert resp =~ "on #{site.domain}"
      assert resp =~ "Need to see the snippet again?"
      assert resp =~ "Run verification later and go to Site Settings?"
      refute resp =~ "modal"
      refute element_exists?(resp, @verification_modal)
    end
  end

  describe "GET /settings/general" do
    test "verification elements render under the snippet", %{conn: conn, site: site} do
      resp =
        conn |> no_slowdown() |> get("/#{site.domain}/settings/general") |> html_response(200)

      assert element_exists?(resp, @verify_button)
      assert element_exists?(resp, @verification_modal)
    end
  end

  describe "LiveView: standalone" do
    test "LiveView mounts", %{conn: conn, site: site} do
      stub_fetch_body(200, "")
      stub_installation()

      {_, html} = get_lv_standalone(conn, site)

      assert html =~ "Verifying your integration"
      assert html =~ "on #{site.domain}"

      assert text_of_element(html, @progress) =~
               "We're visiting your site to ensure that everything is working correctly"
    end

    test "eventually verifies installation", %{conn: conn, site: site} do
      stub_fetch_body(200, source(site.domain))
      stub_installation()

      {:ok, lv} = kick_off_live_verification_standalone(conn, site)

      assert eventually(fn ->
               html = render(lv)

               {
                 text_of_element(html, @progress) =~
                   "Awaiting your first pageview",
                 html
               }
             end)

      html = render(lv)
      assert html =~ "Success!"
      assert html =~ "Your integration is working and visitors are being counted accurately"
    end

    test "eventually fails to verify installation", %{conn: conn, site: site} do
      stub_fetch_body(200, "")
      stub_installation(200, plausible_installed(false))

      {:ok, lv} = kick_off_live_verification_standalone(conn, site)

      assert html =
               eventually(fn ->
                 html = render(lv)
                 {html =~ "", html}

                 {
                   text_of_element(html, @progress) =~
                     "We couldn't find the Plausible snippet on your site",
                   html
                 }
               end)

      refute element_exists?(html, @verification_modal)
      assert element_exists?(html, @retry_button)

      assert html =~ "Please insert the snippet into your site"
    end
  end

  describe "LiveView: modal" do
    test "LiveView mounts", %{conn: conn, site: site} do
      stub_fetch_body(200, "")
      stub_installation()

      {_, html} = get_lv_modal(conn, site)

      text = text(html)

      refute text =~ "Need to see the snippet again?"
      refute text =~ "Run verification later and go to Site Settings?"
      assert element_exists?(html, @verification_modal)
    end

    test "Clicking the Verify modal launches verification", %{conn: conn, site: site} do
      stub_fetch_body(200, source(site.domain))
      stub_installation()

      {lv, html} = get_lv_modal(conn, site)

      assert element_exists?(html, @verification_modal)
      assert element_exists?(html, @verify_button)
      assert text_of_attr(html, @verify_button, "x-on:click") =~ "open-modal"

      assert text_of_element(html, @progress) =~
               "We're visiting your site to ensure that everything is working correctly"

      lv |> element(@verify_button) |> render_click()

      assert html =
               eventually(fn ->
                 html = render(lv)

                 {
                   html =~ "Success!",
                   html
                 }
               end)

      refute html =~ "Awaiting your first pageview"
      assert element_exists?(html, @go_to_dashboard_button)
    end

    test "failed verification can be retried", %{conn: conn, site: site} do
      stub_fetch_body(200, "")
      stub_installation(200, plausible_installed(false))

      {lv, _html} = get_lv_modal(conn, site)

      lv |> element(@verify_button) |> render_click()

      assert html =
               eventually(fn ->
                 html = render(lv)

                 {text_of_element(html, @progress) =~
                    "We couldn't find the Plausible snippet on your site", html}
               end)

      assert element_exists?(html, @retry_button)

      stub_fetch_body(200, source(site.domain))
      stub_installation()

      lv |> element(@retry_button) |> render_click()

      assert eventually(fn ->
               html = render(lv)
               {html =~ "Success!", html}
             end)
    end
  end

  defp get_lv_standalone(conn, site) do
    conn = conn |> no_slowdown() |> assign(:live_module, PlausibleWeb.Live.Verification)
    {:ok, lv, html} = live(conn, "/#{site.domain}")
    {lv, html}
  end

  defp get_lv_modal(conn, site) do
    conn = conn |> no_slowdown() |> assign(:live_module, PlausibleWeb.Live.Verification)
    {:ok, lv, html} = live(no_slowdown(conn), "/#{site.domain}/settings/general")
    {lv, html}
  end

  defp kick_off_live_verification_standalone(conn, site) do
    {:ok, lv, _} =
      live_isolated(conn, PlausibleWeb.Live.Verification,
        session: %{
          "domain" => site.domain,
          "delay" => 0,
          "slowdown" => 0
        }
      )

    {:ok, lv}
  end

  defp no_slowdown(conn) do
    Plug.Conn.put_private(conn, :verification_slowdown, 0)
  end

  defp stub_fetch_body(f) when is_function(f, 1) do
    Req.Test.stub(Plausible.Verification.Checks.FetchBody, f)
  end

  defp stub_installation(f) when is_function(f, 1) do
    Req.Test.stub(Plausible.Verification.Checks.Installation, f)
  end

  defp stub_fetch_body(status, body) do
    stub_fetch_body(fn conn ->
      conn
      |> put_resp_content_type("text/html")
      |> send_resp(status, body)
    end)
  end

  defp stub_installation(status \\ 200, json \\ plausible_installed()) do
    stub_installation(fn conn ->
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(status, Jason.encode!(json))
    end)
  end

  defp plausible_installed(bool \\ true, callback_status \\ 202) do
    %{"data" => %{"plausibleInstalled" => bool, "callbackStatus" => callback_status}}
  end

  defp source(domain) do
    """
    <head>
    <script defer data-domain="#{domain}" src="http://localhost:8000/js/script.js"></script>
    </head>
    """
  end
end
