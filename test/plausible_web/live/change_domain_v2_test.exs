defmodule PlausibleWeb.Live.ChangeDomainV2Test do
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

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
      original_domain = site.domain
      new_domain = "new-example.com"
      {:ok, lv, _html} = live(conn, "/#{site.domain}/change-domain-v2")

      # Submit the form
      lv
      |> element("form")
      |> render_submit(%{site: %{domain: new_domain}})

      # Verify the database was updated
      site = Repo.reload!(site)
      assert site.domain == new_domain
      assert site.domain_changed_from == original_domain
    end

    test "successful form submission navigates to success page", %{conn: conn, site: site} do
      original_domain = site.domain
      new_domain = "new-example.com"
      {:ok, lv, _html} = live(conn, "/#{site.domain}/change-domain-v2")

      lv
      |> element("form")
      |> render_submit(%{site: %{domain: new_domain}})

      assert_patch(lv, "/#{new_domain}/change-domain-v2/success")

      html = render(lv)
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
  end
end
