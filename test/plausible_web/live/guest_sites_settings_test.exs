defmodule PlausibleWeb.Live.GuestSitesSettingsTest do
  use PlausibleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  alias Plausible.Repo
  alias Plausible.Teams

  setup [:create_user, :log_in]

  describe "/settings/guest-sites" do
    test "is linked from the account settings sidebar", %{conn: conn, user: user} do
      add_guest(new_site(), user: user, role: :viewer)

      {:ok, _lv, html} = live(conn, "/settings/guest-sites")

      assert element_exists?(html, ~s|a[href="/settings/guest-sites"]|)
    end

    test "redirects to preferences when the user isn't a guest anywhere", %{
      conn: conn,
      user: user
    } do
      _own_site = new_site(owner: user)

      assert {:error, {:live_redirect, %{to: "/settings/preferences"}}} =
               live(conn, "/settings/guest-sites")
    end

    test "lists guest sites with the role and the owner or team", %{conn: conn, user: user} do
      own_site = new_site(owner: user)

      personal_owner = new_user(name: "Mary Owner")
      personal_site = new_site(owner: personal_owner)
      add_guest(personal_site, user: user, role: :viewer)

      team_site = new_site()
      team = team_site.team |> Teams.complete_setup()
      add_guest(team_site, user: user, role: :editor)

      {:ok, _lv, html} = live(conn, "/settings/guest-sites")

      refute element_exists?(html, "#guest-site-#{own_site.id}")

      assert text_of_element(html, "#guest-site-#{personal_site.id}") =~ personal_site.domain
      assert text_of_element(html, "#guest-site-#{personal_site.id}") =~ "Owned by Mary Owner"
      assert text_of_element(html, "#guest-site-#{personal_site.id}") =~ "Viewer"

      assert text_of_element(html, "#guest-site-#{team_site.id}") =~ team.name
      assert text_of_element(html, "#guest-site-#{team_site.id}") =~ "Editor"
    end

    test "leaving a site removes the guest membership", %{conn: conn, user: user} do
      site = new_site()
      add_guest(site, user: user, role: :viewer)
      other_site = new_site()
      add_guest(other_site, user: user, role: :viewer)

      {:ok, lv, _html} = live(conn, "/settings/guest-sites")

      html = lv |> element("#guest-site-#{site.id}-leave") |> render_click()

      assert text(html) =~ "You have left #{site.domain}"
      refute element_exists?(html, "#guest-site-#{site.id}")
      assert element_exists?(html, "#guest-site-#{other_site.id}")
      assert {:error, :not_a_member} = Teams.Memberships.site_role(site, user)
    end

    test "leaving the last guest site redirects to preferences", %{conn: conn, user: user} do
      site = new_site()
      add_guest(site, user: user, role: :viewer)

      {:ok, lv, _html} = live(conn, "/settings/guest-sites")

      lv |> element("#guest-site-#{site.id}-leave") |> render_click()

      flash = assert_redirect(lv, "/settings/preferences")
      assert flash["success"] == "You have left #{site.domain}"
      assert {:error, :not_a_member} = Teams.Memberships.site_role(site, user)
    end

    test "leaving a site the user isn't a guest of does nothing", %{conn: conn, user: user} do
      own_site = new_site(owner: user)
      add_guest(new_site(), user: user, role: :viewer)

      {:ok, lv, _html} = live(conn, "/settings/guest-sites")

      html = render_click(lv, "leave-site", %{"site-id" => to_string(own_site.id)})

      assert text(html) =~ "You're no longer a guest of this site"
      assert {:ok, {:team_member, :owner}} = Teams.Memberships.site_role(own_site, user)
    end
  end

  on_ee do
    describe "/settings/guest-sites - SSO user" do
      setup [:create_team, :setup_sso, :provision_sso_user, :log_in]

      test "leaving a guest site keeps the SSO user", %{conn: conn, user: user} do
        site = new_site()
        add_guest(site, user: Repo.reload!(user), role: :viewer)
        other_site = new_site()
        add_guest(other_site, user: Repo.reload!(user), role: :viewer)

        {:ok, lv, _html} = live(conn, "/settings/guest-sites")

        html = lv |> element("#guest-site-#{site.id}-leave") |> render_click()

        assert text(html) =~ "You have left #{site.domain}"
        assert {:error, :not_a_member} = Teams.Memberships.site_role(site, user)
        assert %{type: :sso} = Repo.reload(user)
      end
    end
  end
end
