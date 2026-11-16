defmodule PlausibleWeb.SettingsController.GuestSitesTest do
  use PlausibleWeb.ConnCase, async: true
  use Bamboo.Test
  use Plausible.Repo

  describe "GET /settings/guest-sites" do
    setup [:create_user, :log_in]

    test "is linked from the account settings sidebar", %{conn: conn, user: user} do
      add_guest(new_site(), user: user, role: :viewer)

      conn = get(conn, ~p"/settings/guest-sites")

      assert element_exists?(html_response(conn, 200), ~s|a[href="/settings/guest-sites"]|)
    end

    test "redirects to preferences when the user isn't a guest anywhere", %{
      conn: conn,
      user: user
    } do
      _own_site = new_site(owner: user)

      conn = get(conn, ~p"/settings/guest-sites")

      assert redirected_to(conn, 302) == ~p"/settings/preferences"
    end

    test "lists guest sites with the role and the owner or team", %{conn: conn, user: user} do
      own_site = new_site(owner: user)

      personal_owner = new_user(name: "Mary Owner")
      personal_site = new_site(owner: personal_owner)
      add_guest(personal_site, user: user, role: :viewer)

      team_site = new_site()
      team = team_site.team |> Plausible.Teams.complete_setup()
      add_guest(team_site, user: user, role: :editor)

      conn = get(conn, ~p"/settings/guest-sites")
      html = html_response(conn, 200)

      refute element_exists?(html, "#guest-site-#{own_site.id}")

      assert text_of_element(html, "#guest-site-#{personal_site.id}") =~ personal_site.domain
      assert text_of_element(html, "#guest-site-#{personal_site.id}") =~ "Owned by Mary Owner"
      assert text_of_element(html, "#guest-site-#{personal_site.id}") =~ "Viewer"

      assert text_of_element(html, "#guest-site-#{team_site.id}") =~ team.name
      assert text_of_element(html, "#guest-site-#{team_site.id}") =~ "Editor"
    end
  end

  describe "DELETE /settings/guest-sites/:site_id" do
    setup [:create_user, :log_in]

    test "removes the guest membership", %{conn: conn, user: user} do
      site = new_site()
      add_guest(site, user: user, role: :viewer)
      other_site = new_site()
      add_guest(other_site, user: user, role: :viewer)

      conn = delete(conn, ~p"/settings/guest-sites/#{site.id}")

      assert redirected_to(conn, 302) == ~p"/settings/guest-sites"
      assert Phoenix.Flash.get(conn.assigns.flash, :success) == "You have left #{site.domain}"
      assert {:error, :not_a_member} = Plausible.Teams.Memberships.site_role(site, user)

      assert {:ok, {:guest_member, :viewer}} =
               Plausible.Teams.Memberships.site_role(other_site, user)

      assert_no_emails_delivered()
    end

    test "leaving the last guest site ends up on preferences", %{conn: conn, user: user} do
      site = new_site()
      add_guest(site, user: user, role: :viewer)

      conn = delete(conn, ~p"/settings/guest-sites/#{site.id}")
      conn = get(recycle(conn), redirected_to(conn, 302))

      assert redirected_to(conn, 302) == ~p"/settings/preferences"
      assert Phoenix.Flash.get(conn.assigns.flash, :success) == "You have left #{site.domain}"
    end

    test "does nothing for a site the user isn't a guest of", %{conn: conn, user: user} do
      own_site = new_site(owner: user)
      add_guest(new_site(), user: user, role: :viewer)

      conn = delete(conn, ~p"/settings/guest-sites/#{own_site.id}")

      assert redirected_to(conn, 302) == ~p"/settings/guest-sites"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You're no longer a guest of this site"

      assert {:ok, {:team_member, :owner}} =
               Plausible.Teams.Memberships.site_role(own_site, user)
    end
  end

  on_ee do
    describe "DELETE /settings/guest-sites/:site_id - SSO user" do
      setup [:create_user, :create_team, :setup_sso, :provision_sso_user, :log_in]

      test "leaving a guest site keeps the SSO user", %{conn: conn, user: user} do
        site = new_site()
        add_guest(site, user: Repo.reload!(user), role: :viewer)

        conn = delete(conn, ~p"/settings/guest-sites/#{site.id}")

        assert Phoenix.Flash.get(conn.assigns.flash, :success) == "You have left #{site.domain}"
        assert {:error, :not_a_member} = Plausible.Teams.Memberships.site_role(site, user)
        assert %{type: :sso} = Repo.reload(user)
      end
    end
  end
end
