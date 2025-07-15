defmodule PlausibleWeb.Live.VerificationTest do
  use PlausibleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  setup [:create_user, :log_in, :create_site]

  # @verify_button ~s|button#launch-verification-button[phx-click="launch-verification"]|
  @retry_button ~s|a[phx-click="retry"]|
  # @go_to_dashboard_button ~s|a[href$="?skip_to_dashboard=true"]|
  @progress ~s|#progress-indicator p#progress|
  @awaiting ~s|#progress-indicator p#awaiting|
  @heading ~s|#progress-indicator h2|

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
      stub_fetch_body(200, "")
      stub_installation()

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
    test "eventually verifies installation", %{conn: conn, site: site} do
      stub_fetch_body(200, source(site.domain))
      stub_installation()

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

      stub_fetch_body(200, source(site.domain))
      stub_installation()

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
      stub_fetch_body(200, source(site.domain))
      stub_installation()

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

    @tag :ee_only
    test "eventually fails to verify installation", %{conn: conn, site: site} do
      stub_fetch_body(200, "")
      stub_installation(200, plausible_installed(false))

      {:ok, lv} = kick_off_live_verification(conn, site)

      assert html =
               eventually(fn ->
                 html = render(lv)
                 {html =~ "", html}

                 {
                   text_of_element(html, @heading) =~
                     "We couldn't find the Plausible snippet",
                   html
                 }
               end)

      assert element_exists?(html, @retry_button)

      assert html =~ "Please insert the snippet into your site"
      refute element_exists?(html, "#super-admin-report")
    end
  end

  defp get_lv(conn, site) do
    {:ok, lv, html} = conn |> no_slowdown() |> live("/#{site.domain}/verification")

    {lv, html}
  end

  defp kick_off_live_verification(conn, site) do
    {:ok, lv, _html} = conn |> no_slowdown() |> no_delay() |> live("/#{site.domain}/verification")
    {:ok, lv}
  end

  defp no_slowdown(conn) do
    Plug.Conn.put_private(conn, :slowdown, 0)
  end

  defp no_delay(conn) do
    Plug.Conn.put_private(conn, :delay, 0)
  end

  defp stub_fetch_body(f) when is_function(f, 1) do
    Req.Test.stub(Plausible.InstallationSupport.Checks.FetchBody, f)
  end

  defp stub_installation(f) when is_function(f, 1) do
    Req.Test.stub(Plausible.InstallationSupport.Checks.Installation, f)
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
    %{
      "data" => %{
        "completed" => true,
        "snippetsFoundInHead" => 0,
        "snippetsFoundInBody" => 0,
        "plausibleInstalled" => bool,
        "callbackStatus" => callback_status
      }
    }
  end

  defp source(domain) do
    """
    <head>
    <script defer data-domain="#{domain}" src="http://localhost:8000/js/script.js"></script>
    </head>
    """
  end
end
