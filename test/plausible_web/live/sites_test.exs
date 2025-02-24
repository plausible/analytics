defmodule PlausibleWeb.Live.SitesTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Teams.Test

  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  alias Plausible.Repo

  setup [:create_user, :log_in]

  describe "/sites" do
    test "renders empty sites page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, "/sites")

      assert text(html) =~ "You don't have any sites yet"
    end

    test "renders team invitations", %{user: user, conn: conn} do
      owner1 = new_user(name: "G.I. Joe")
      new_site(owner: owner1)
      team1 = team_of(owner1)

      owner2 = new_user(name: "G.I. Jane")
      new_site(owner: owner2)
      team2 = team_of(owner2)

      invitation1 = invite_member(team1, user, inviter: owner1, role: :viewer)
      invitation2 = invite_member(team2, user, inviter: owner2, role: :editor)

      {:ok, _lv, html} = live(conn, "/sites")

      assert text_of_element(html, "#invitation-#{invitation1.invitation_id}") =~
               "G.I. Joe has invited you to join the \"My Personal Sites\" as viewer member."

      assert text_of_element(html, "#invitation-#{invitation2.invitation_id}") =~
               "G.I. Jane has invited you to join the \"My Personal Sites\" as editor member."

      assert find(
               html,
               "#invitation-#{invitation1.invitation_id} a[href=#{Routes.invitation_path(PlausibleWeb.Endpoint, :accept_invitation, invitation1.invitation_id)}]"
             )

      assert find(
               html,
               "#invitation-#{invitation1.invitation_id} a[href=#{Routes.invitation_path(PlausibleWeb.Endpoint, :reject_invitation, invitation1.invitation_id)}]"
             )

      assert find(
               html,
               "#invitation-#{invitation2.invitation_id} a[href=#{Routes.invitation_path(PlausibleWeb.Endpoint, :accept_invitation, invitation2.invitation_id)}]"
             )

      assert find(
               html,
               "#invitation-#{invitation2.invitation_id} a[href=#{Routes.invitation_path(PlausibleWeb.Endpoint, :reject_invitation, invitation2.invitation_id)}]"
             )
    end

    test "renders metadata for invitation", %{
      conn: conn,
      user: user
    } do
      inviter = new_user()
      site = new_site(owner: inviter)

      invitation = invite_guest(site, user, inviter: inviter, role: :viewer)

      {:ok, _lv, html} = live(conn, "/sites")

      invitation_data = get_invitation_data(html)

      assert get_in(invitation_data, ["invitations", invitation.invitation_id, "invitation"])
    end

    @tag :ee_only
    test "renders ownership transfer invitation for a case with no plan", %{
      conn: conn,
      user: user
    } do
      inviter = new_user()
      site = new_site(owner: inviter)

      transfer = invite_transfer(site, user, inviter: inviter)

      {:ok, _lv, html} = live(conn, "/sites")

      invitation_data = get_invitation_data(html)

      assert get_in(invitation_data, ["invitations", transfer.transfer_id, "no_plan"])
    end

    @tag :ee_only
    test "renders ownership transfer invitation for a case with exceeded limits", %{
      conn: conn,
      user: user
    } do
      inviter = new_user()
      site = new_site(owner: inviter)

      transfer = invite_transfer(site, user, inviter: inviter)

      # fill site quota
      subscribe_to_growth_plan(user)
      for _ <- 1..10, do: new_site(owner: user)

      {:ok, _lv, html} = live(conn, "/sites")

      invitation_data = get_invitation_data(html)

      assert get_in(invitation_data, ["invitations", transfer.transfer_id, "exceeded_limits"]) ==
               "site limit"
    end

    @tag :ee_only
    test "renders ownership transfer invitation for a case with missing features", %{
      conn: conn,
      user: user
    } do
      inviter = new_user()
      site = new_site(owner: inviter, allowed_event_props: ["dummy"])

      transfer = invite_transfer(site, user, inviter: inviter)

      subscribe_to_growth_plan(user)

      {:ok, _lv, html} = live(conn, "/sites")

      invitation_data = get_invitation_data(html)

      assert get_in(invitation_data, ["invitations", transfer.transfer_id, "missing_features"]) ==
               "Custom Properties"
    end

    test "renders 24h visitors correctly", %{conn: conn, user: user} do
      site = new_site(owner: user)

      populate_stats(site, [build(:pageview), build(:pageview), build(:pageview)])

      {:ok, _lv, html} = live(conn, "/sites")

      site_card = text_of_element(html, "li[data-domain=\"#{site.domain}\"]")
      assert site_card =~ "3 visitors in last 24h"
      assert site_card =~ site.domain
    end

    test "filters by domain", %{conn: conn, user: user} do
      _site1 = new_site(domain: "first.example.com", owner: user)
      _site2 = new_site(domain: "second.example.com", owner: user)
      _site3 = new_site(domain: "first-another.example.com", owner: user)

      {:ok, lv, _html} = live(conn, "/sites")

      type_into_input(lv, "filter_text", "firs")
      html = render(lv)

      assert html =~ "first.example.com"
      assert html =~ "first-another.example.com"
      refute html =~ "second.example.com"
    end

    test "filtering plays well with pagination", %{conn: conn, user: user} do
      _site1 = new_site(domain: "first.another.example.com", owner: user)
      _site2 = new_site(domain: "second.example.com", owner: user)
      _site3 = new_site(domain: "third.another.example.com", owner: user)

      {:ok, lv, html} = live(conn, "/sites?page_size=2")

      assert html =~ "first.another.example.com"
      assert html =~ "second.example.com"
      refute html =~ "third.another.example.com"
      assert html =~ "page=2"
      refute html =~ "page=1"

      type_into_input(lv, "filter_text", "anot")
      html = render(lv)

      assert html =~ "first.another.example.com"
      refute html =~ "second.example.com"
      assert html =~ "third.another.example.com"
      refute html =~ "page=1"
      refute html =~ "page=2"
    end
  end

  describe "pinning" do
    test "renders pin site option when site not pinned", %{conn: conn, user: user} do
      site = new_site(owner: user)

      {:ok, _lv, html} = live(conn, "/sites")

      assert text_of_element(
               html,
               ~s/li[data-domain="#{site.domain}"] a[phx-value-domain]/
             ) == "Pin Site"
    end

    test "site state changes when pin toggled", %{conn: conn, user: user} do
      site = new_site(owner: user)

      {:ok, lv, _html} = live(conn, "/sites")

      button_selector = ~s/li[data-domain="#{site.domain}"] a[phx-value-domain]/

      html =
        lv
        |> element(button_selector)
        |> render_click()

      assert html =~ "Site pinned"

      assert text_of_element(html, button_selector) == "Unpin Site"

      html =
        lv
        |> element(button_selector)
        |> render_click()

      assert html =~ "Site unpinned"

      assert text_of_element(html, button_selector) == "Pin Site"
    end

    test "shows error when pins limit hit", %{conn: conn, user: user} do
      for _ <- 1..9 do
        site = new_site(owner: user)
        assert {:ok, _} = Plausible.Sites.toggle_pin(user, site)
      end

      site = new_site(owner: user)

      {:ok, lv, _html} = live(conn, "/sites")

      button_selector = ~s/li[data-domain="#{site.domain}"] a[phx-value-domain]/

      html =
        lv
        |> element(button_selector)
        |> render_click()

      assert text(html) =~ "Looks like you've hit the pinned sites limit!"
    end

    test "does not allow pinning site user doesn't have access to", %{conn: conn, user: user} do
      site = new_site()

      {:ok, lv, _html} = live(conn, "/sites")

      render_click(lv, "pin-toggle", %{"domain" => site.domain})

      refute Repo.get_by(Plausible.Site.UserPreference, user_id: user.id, site_id: site.id)
    end
  end

  defp type_into_input(lv, id, text) do
    lv
    |> element("form")
    |> render_change(%{id => text})
  end

  defp get_invitation_data(html) do
    html
    |> text_of_attr("div[x-data]", "x-data")
    |> String.trim("dropdown")
    |> String.replace("selectedInvitation:", "\"selectedInvitation\":")
    |> String.replace("invitationOpen:", "\"invitationOpen\":")
    |> String.replace("invitations:", "\"invitations\":")
    |> Jason.decode!()
  end
end
