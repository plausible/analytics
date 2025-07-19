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

      text = text(html)
      assert text =~ "Meine Websites"
      assert text =~ "You don't have any sites yet"
      refute text =~ "You currently have no personal sites"
      refute text =~ "Go to your team"
    end

    test "renders team switcher link, if on personal sites with other teams available", %{
      conn: conn,
      user: user
    } do
      team2 = new_site().team

      add_member(team2, user: user, role: :admin)

      {:ok, _lv, html} = live(conn, "/sites")
      text = text(html)

      assert text =~ "Meine Websites"
      refute text =~ "You don't have any sites yet"
      assert text =~ "You currently have no personal sites"
      assert text =~ "Go to your team"
    end

    test "renders settings link when current team is set", %{user: user, conn: conn} do
      {:ok, _lv, html} = live(conn, "/sites")

      refute element_exists?(html, ~s|a[data-test-id="team-settings-link"]|)

      new_site(owner: user)
      team = team_of(user)
      team = Plausible.Teams.complete_setup(team)

      conn = set_current_team(conn, team)

      {:ok, _lv, html} = live(conn, "/sites")

      assert element_exists?(html, ~s|a[data-test-id="team-settings-link"]|)
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
               "G.I. Joe has invited you to join the \"Meine Websites\" as viewer member."

      assert text_of_element(html, "#invitation-#{invitation2.invitation_id}") =~
               "G.I. Jane has invited you to join the \"Meine Websites\" as editor member."

      assert [_] =
               find(
                 html,
                 ~s|#invitation-#{invitation1.invitation_id} a[href="#{Routes.invitation_path(PlausibleWeb.Endpoint, :accept_invitation, invitation1.invitation_id)}"]|
               )

      assert [_] =
               find(
                 html,
                 ~s|#invitation-#{invitation1.invitation_id} a[href="#{Routes.invitation_path(PlausibleWeb.Endpoint, :reject_invitation, invitation1.invitation_id)}"]|
               )

      assert [_] =
               find(
                 html,
                 ~s|#invitation-#{invitation2.invitation_id} a[href="#{Routes.invitation_path(PlausibleWeb.Endpoint, :accept_invitation, invitation2.invitation_id)}"]|
               )

      assert [_] =
               find(
                 html,
                 ~s|#invitation-#{invitation2.invitation_id} a[href="#{Routes.invitation_path(PlausibleWeb.Endpoint, :reject_invitation, invitation2.invitation_id)}"]|
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
    test "renders upgrade nag when current team has a site and trial expired", %{
      conn: conn,
      user: user
    } do
      team = new_site(owner: user).team

      team
      |> Ecto.Changeset.change(trial_expiry_date: Date.add(Date.utc_today(), -1))
      |> Repo.update!()

      {:ok, _lv, html} = live(conn, "/sites")

      assert html =~ "Payment required"
    end

    @tag :ee_only
    test "renders upgrade nag when there's a pending transfer", %{
      conn: conn,
      user: user
    } do
      {:ok, personal_team} = Plausible.Teams.get_or_create(user)

      another_user = new_user()
      site = new_site(owner: another_user)

      personal_team
      |> Ecto.Changeset.change(trial_expiry_date: Date.add(Date.utc_today(), -1))
      |> Repo.update!()

      invite_transfer(site, user, inviter: another_user)

      {:ok, _lv, html} = live(conn, "/sites")

      assert html =~ "Payment required"
    end

    @tag :ee_only
    test "does not render upgrade nag when there's no current team", %{conn: conn, user: user} do
      team = new_site().team |> Plausible.Teams.complete_setup()
      add_member(team, user: user, role: :owner)

      {:ok, _lv, html} = live(conn, "/sites")

      refute html =~ "Payment required"
    end

    @tag :ee_only
    test "does not render upgrade nag when current team has no sites and user has no pending transfers",
         %{conn: conn, user: user} do
      {:ok, _personal_team} = Plausible.Teams.get_or_create(user)

      team = new_site().team |> Plausible.Teams.complete_setup()
      add_member(team, user: user, role: :owner)

      {:ok, _lv, html} = live(conn, "/sites")

      refute html =~ "Payment required"
    end

    @tag :ee_only
    test "does not render upgrade nag if current team does not have any sites yet and user has no pending transfers",
         %{conn: conn, user: user} do
      {:ok, personal_team} = Plausible.Teams.get_or_create(user)

      personal_team
      |> Ecto.Changeset.change(trial_expiry_date: Date.add(Date.utc_today(), -1))
      |> Repo.update!()

      team = new_site().team |> Plausible.Teams.complete_setup()
      add_member(team, user: user, role: :owner)

      {:ok, _lv, html} = live(conn, "/sites")

      refute html =~ "Payment required"
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

      type_into_input(lv, "filter-text", "firs")
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

      type_into_input(lv, "filter-text", "anot")
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
    |> text_of_attr("div[x-ref=\"invitation_data\"][x-data]", "x-data")
    |> String.trim("dropdown")
    |> String.replace("selectedInvitation:", "\"selectedInvitation\":")
    |> String.replace("invitationOpen:", "\"invitationOpen\":")
    |> String.replace("invitations:", "\"invitations\":")
    |> Jason.decode!()
  end
end
