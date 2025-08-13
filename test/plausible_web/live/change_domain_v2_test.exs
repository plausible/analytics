defmodule PlausibleWeb.Live.ChangeDomainV2Test do
  use PlausibleWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Plausible.TestUtils
  import ExUnit.CaptureLog

  alias Plausible.Repo

  describe "ChangeDomainV2 LiveView" do
    setup [:create_user, :log_in, :create_site]

    test "mounts and renders form", %{conn: conn, site: site} do
      {:ok, _lv, html} = live(conn, "/#{site.domain}/change-domain-v2")

      assert html =~ "Change your website domain"
    end

    test "form submission when no change is made", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, "/#{site.domain}/change-domain-v2")

      html =
        lv
        |> element("form")
        |> render_submit(%{site: %{domain: site.domain}})

      assert html =~ "New domain must be different than the current one"
    end

    test "form submission to an existing domain", %{conn: conn, site: site} do
      another_site = insert(:site)
      {:ok, lv, _html} = live(conn, "/#{site.domain}/change-domain-v2")

      html =
        lv
        |> element("form")
        |> render_submit(%{site: %{domain: another_site.domain}})

      assert html =~ "This domain cannot be registered"

      site = Repo.reload!(site)
      assert site.domain != another_site.domain
      assert is_nil(site.domain_changed_from)
    end

    test "form submission to a domain in transition period", %{conn: conn, site: site} do
      _another_site = insert(:site, domain_changed_from: "foo.example.com")
      {:ok, lv, _html} = live(conn, "/#{site.domain}/change-domain-v2")

      html =
        lv
        |> element("form")
        |> render_submit(%{site: %{domain: "foo.example.com"}})

      assert html =~ "This domain cannot be registered"

      site = Repo.reload!(site)
      assert site.domain != "foo.example.com"
      assert is_nil(site.domain_changed_from)
    end

    test "successful form submission updates database", %{conn: conn, site: site} do
      stub_detection_result(%{
        "v1Detected" => false,
        "gtmLikely" => false,
        "wordpressLikely" => false,
        "wordpressPlugin" => false
      })

      original_domain = site.domain
      new_domain = "new-example.com"
      {:ok, lv, _html} = live(conn, "/#{site.domain}/change-domain-v2")

      lv
      |> element("form")
      |> render_submit(%{site: %{domain: new_domain}})

      site = Repo.reload!(site)
      assert site.domain == new_domain
      assert site.domain_changed_from == original_domain
    end

    test "successful form submission navigates to success page", %{conn: conn, site: site} do
      stub_detection_result(%{
        "v1Detected" => false,
        "gtmLikely" => false,
        "wordpressLikely" => false,
        "wordpressPlugin" => false
      })

      original_domain = site.domain
      new_domain = "new-example.com"
      {:ok, lv, _html} = live(conn, "/#{site.domain}/change-domain-v2")

      lv
      |> element("form")
      |> render_submit(%{site: %{domain: new_domain}})

      assert_patch(lv, "/#{new_domain}/change-domain-v2/success")

      html = render_async(lv, 500)
      assert html =~ "Domain Changed Successfully"
      assert html =~ original_domain
      assert html =~ new_domain
    end

    test "form validation shows error for empty domain", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, "/#{site.domain}/change-domain-v2")

      html =
        lv
        |> element("form")
        |> render_submit(%{site: %{domain: ""}})

      assert html =~ "can&#39;t be blank"
    end

    test "form validation shows error for invalid domain format", %{conn: conn, site: site} do
      {:ok, lv, _html} = live(conn, "/#{site.domain}/change-domain-v2")

      html =
        lv
        |> element("form")
        |> render_submit(%{site: %{domain: "invalid domain with spaces"}})

      assert html =~ "only letters, numbers, slashes and period allowed"
    end

    test "renders back to settings link with correct path", %{conn: conn, site: site} do
      {:ok, _lv, html} = live(conn, "/#{site.domain}/change-domain-v2")

      expected_link = Routes.site_path(conn, :settings_general, site.domain)
      assert html =~ expected_link
    end

    test "success page shows WordPress plugin notice when detected", %{conn: conn, site: site} do
      stub_detection_result(%{
        "v1Detected" => true,
        "gtmLikely" => false,
        "wordpressLikely" => true,
        "wordpressPlugin" => true
      })

      new_domain = "new-example.com"
      {:ok, lv, _html} = live(conn, "/#{site.domain}/change-domain-v2")

      lv
      |> element("form")
      |> render_submit(%{site: %{domain: new_domain}})

      assert_patch(lv, "/#{new_domain}/change-domain-v2/success")

      html = render_async(lv, 500)
      assert html =~ "<i>must</i>"
      assert html =~ "also update the site"
      assert html =~ "Plausible Wordpress Plugin settings"
      assert html =~ "within 72 hours"
    end

    test "success page shows generic v1 notice when detected but not WordPress", %{
      conn: conn,
      site: site
    } do
      stub_detection_result(%{
        "v1Detected" => true,
        "gtmLikely" => false,
        "wordpressLikely" => false,
        "wordpressPlugin" => false
      })

      new_domain = "new-example.com"
      {:ok, lv, _html} = live(conn, "/#{site.domain}/change-domain-v2")

      lv
      |> element("form")
      |> render_submit(%{site: %{domain: new_domain}})

      assert_patch(lv, "/#{new_domain}/change-domain-v2/success")

      html = render_async(lv, 500)
      assert html =~ "<i>must</i>"
      assert html =~ "also update the site"
      assert html =~ "Plausible Installation"
      assert html =~ "within 72 hours"
      refute html =~ "Wordpress Plugin"
    end

    test "success page shows no notice when no v1 tracking detected", %{conn: conn, site: site} do
      stub_detection_result(%{
        "v1Detected" => false,
        "gtmLikely" => false,
        "wordpressLikely" => false,
        "wordpressPlugin" => false
      })

      new_domain = "new-example.com"
      {:ok, lv, _html} = live(conn, "/#{site.domain}/change-domain-v2")

      lv
      |> element("form")
      |> render_submit(%{site: %{domain: new_domain}})

      assert_patch(lv, "/#{new_domain}/change-domain-v2/success")

      html = render_async(lv, 500)
      refute html =~ "Additional Steps Required"
      refute html =~ "<i>must</i>"
      refute html =~ "also update the site"
    end

    test "success page handles detection error gracefully", %{conn: conn, site: site} do
      stub_detection_error()

      capture_log(fn ->
        new_domain = "new-example.com"
        {:ok, lv, _html} = live(conn, "/#{site.domain}/change-domain-v2")

        lv
        |> element("form")
        |> render_submit(%{site: %{domain: new_domain}})

        assert_patch(lv, "/#{new_domain}/change-domain-v2/success")

        html = render_async(lv, 500)
        assert html =~ "Additional Steps Required"
        assert html =~ "<i>must</i>"
        assert html =~ "also update the site"
        assert html =~ "Plausible Installation"
      end)
    end
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
      |> send_resp(200, Jason.encode!(%{"data" => %{"error" => "Simulated browser error"}}))
    end)
  end
end
