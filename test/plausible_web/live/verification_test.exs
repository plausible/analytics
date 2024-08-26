defmodule PlausibleWeb.Live.VerificationTest do
  use PlausibleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  setup [:create_user, :log_in, :create_site]

  # @verify_button ~s|button#launch-verification-button[phx-click="launch-verification"]|
  @retry_button ~s|a[phx-click="retry"]|
  # @go_to_dashboard_button ~s|a[href$="?skip_to_dashboard=true"]|
  @progress ~s|#progress-indicator p#progress|
  @heading ~s|#progress-indicator h3|

  describe "GET /:domain" do
    test "static verification screen renders", %{conn: conn, site: site} do
      resp =
        get(conn, conn |> no_slowdown() |> get("/#{site.domain}") |> redirected_to)
        |> html_response(200)

      assert text_of_element(resp, @progress) =~
               "We're visiting your site to ensure that everything is working"

      assert resp =~ "Verifying your installation"
    end
  end

  describe "LiveView" do
    test "LiveView mounts", %{conn: conn, site: site} do
      stub_fetch_body(200, "")
      stub_installation()

      {_, html} = get_lv(conn, site)

      assert html =~ "Verifying your installation"

      assert text_of_element(html, @progress) =~
               "We're visiting your site to ensure that everything is working"
    end

    test "eventually verifies installation", %{conn: conn, site: site} do
      stub_fetch_body(200, source(site.domain))
      stub_installation()

      {:ok, lv} = kick_off_live_verification(conn, site)

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
      assert html =~ "Your integration is working"
    end

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

      refute text_of_element(html, @progress) =~ "Awaiting your first pageview"
      refute_redirected(lv, "http://localhost:8000/#{URI.encode_www_form(site.domain)}")
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

      assert_redirect(lv, "http://localhost:8000/#{URI.encode_www_form(site.domain)}/")
    end

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
    end
  end

  defp get_lv(conn, site) do
    {:ok, lv, html} = conn |> no_slowdown() |> live("/#{site.domain}/verification")

    {lv, html}
  end

  defp kick_off_live_verification(conn, site) do
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
