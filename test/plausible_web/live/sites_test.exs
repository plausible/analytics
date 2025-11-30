defmodule PlausibleWeb.Live.SitesTest do
  use PlausibleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Plausible.Repo

  setup [:create_user, :log_in]

  describe "/sites" do
    test "renders empty sites page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, "/sites")

      text = text(html)

      assert text =~ "My personal sites"
      assert text =~ "Add your first personal site"
      refute text =~ "Go to team sites"
    end

    test "renders team switcher link, if on personal sites with other teams available", %{
      conn: conn,
      user: user
    } do
      team2 = new_site().team

      add_member(team2, user: user, role: :admin)

      {:ok, _lv, html} = live(conn, "/sites")
      text = text(html)

      assert text =~ "My personal sites"
      refute text =~ "You don't have any sites yet"
      assert text =~ "Add your first personal site"
      assert text =~ "Go to team sites"
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
               "G.I. Joe has invited you to join the \"My personal sites\" as viewer member."

      assert text_of_element(html, "#invitation-#{invitation2.invitation_id}") =~
               "G.I. Jane has invited you to join the \"My personal sites\" as editor member."

      assert element_exists?(
               html,
               ~s|#invitation-#{invitation1.invitation_id} a[href="#{Routes.invitation_path(PlausibleWeb.Endpoint, :accept_invitation, invitation1.invitation_id)}"]|
             )

      assert element_exists?(
               html,
               ~s|#invitation-#{invitation1.invitation_id} a[href="#{Routes.invitation_path(PlausibleWeb.Endpoint, :reject_invitation, invitation1.invitation_id)}"]|
             )

      assert element_exists?(
               html,
               ~s|#invitation-#{invitation2.invitation_id} a[href="#{Routes.invitation_path(PlausibleWeb.Endpoint, :accept_invitation, invitation2.invitation_id)}"]|
             )

      assert element_exists?(
               html,
               ~s|#invitation-#{invitation2.invitation_id} a[href="#{Routes.invitation_path(PlausibleWeb.Endpoint, :reject_invitation, invitation2.invitation_id)}"]|
             )
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

      assert text_of_element(html, "#invitation-modal-#{transfer.transfer_id}") =~
               "You are unable to accept the ownership of this site because your account does not have a subscription"
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

      assert text_of_element(html, "#invitation-modal-#{transfer.transfer_id}") =~
               "Owning this site would exceed your site limit"
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

      assert text_of_element(html, "#invitation-modal-#{transfer.transfer_id}") =~
               "The site uses Custom Properties, which your current subscription does not support"
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

  on_ee do
    describe "consolidated views appearance" do
      test "consolidated view shows up", %{conn: conn, user: user} do
        new_site(owner: user)
        new_site(owner: user)
        team = user |> team_of()

        conn = set_current_team(conn, team)

        {:ok, _lv, html} = live(conn, "/sites")

        refute element_exists?(html, ~s|[data-test-id="consolidated-view-card"]|)

        team = Plausible.Teams.complete_setup(team)
        conn = set_current_team(conn, team)

        {:ok, _lv, html} = live(conn, "/sites")

        assert element_exists?(html, ~s|[data-test-id="consolidated-view-card"]|)
        assert element_exists?(html, ~s|[data-test-id="consolidated-view-stats-loaded"]|)
        assert element_exists?(html, ~s|[data-test-id="consolidated-view-chart-loaded"]|)
      end

      test "consolidated view presents consolidated stats", %{conn: conn, user: user} do
        site1 = new_site(owner: user)
        site2 = new_site(owner: user)

        populate_stats(site1, [
          build(:pageview, user_id: 1),
          build(:pageview, user_id: 1),
          build(:pageview)
        ])

        populate_stats(site2, [
          build(:pageview, user_id: 3)
        ])

        team = user |> team_of() |> Plausible.Teams.complete_setup()

        conn = set_current_team(conn, team)

        {:ok, _lv, html} = live(conn, "/sites")

        stats = text_of_element(html, ~s|[data-test-id="consolidated-view-stats-loaded"]|)
        assert stats =~ "Unique visitors 3"
        assert stats =~ "Total visits 3"
        assert stats =~ "Total pageviews 4"
        assert stats =~ "Views per visit 1.33"
      end

      test "consolidated view disappears when trial ends - CTA is shown instead", %{
        conn: conn,
        user: user
      } do
        new_site(owner: user)
        new_site(owner: user)
        team = user |> team_of() |> Plausible.Teams.complete_setup()

        conn = set_current_team(conn, team)

        {:ok, _lv, html} = live(conn, "/sites")

        refute element_exists?(html, ~s|[data-test-id="consolidated-view-card-cta"]|)
        assert element_exists?(html, ~s|[data-test-id="consolidated-view-card"]|)

        team |> Plausible.Teams.Team.end_trial() |> Plausible.Repo.update!()

        {:ok, _lv, html} = live(conn, "/sites")

        refute element_exists?(html, ~s|[data-test-id="consolidated-view-card"]|)
        assert element_exists?(html, ~s|[data-test-id="consolidated-view-card-cta"]|)

        assert text_of_element(html, ~s|[data-test-id="consolidated-view-card-cta"]|) =~
                 "Upgrade to the Business plan to enable consolidated view."

        assert element_exists?(
                 html,
                 ~s|[data-test-id="consolidated-view-card-cta"] a[href$="/billing/choose-plan"]|
               )
      end

      test "CTA for insufficient custom plans", %{conn: conn, user: user} do
        user
        |> subscribe_to_enterprise_plan(features: [Plausible.Billing.Feature.Goals])
        |> team_of()

        new_site(owner: user)
        new_site(owner: user)

        {:ok, _lv, html} = live(conn, "/sites")

        assert element_exists?(html, ~s|[data-test-id="consolidated-view-card-cta"]|)

        assert text_of_element(html, ~s|[data-test-id="consolidated-view-card-cta"]|) =~
                 "Your plan does not include consolidated view. Contact us to discuss an upgrade."
      end

      test "a team that hasn't been set up shows different CTA", %{
        conn: conn,
        user: user
      } do
        new_site(owner: user)
        new_site(owner: user)

        {:ok, _lv, html} = live(conn, "/sites")

        assert element_exists?(html, ~s|[data-test-id="consolidated-view-card-cta"]|)

        assert text_of_element(html, ~s|[data-test-id="consolidated-view-card-cta"]|) =~
                 "To create a consolidated view, you'll need to set up a team."
      end

      test "single site won't show neither CTA or view - team not setup", %{
        conn: conn,
        user: user
      } do
        new_site(owner: user)

        {:ok, _lv, html} = live(conn, "/sites")

        refute element_exists?(html, ~s|[data-test-id="consolidated-view-card-cta"]|)
        refute element_exists?(html, ~s|[data-test-id="consolidated-view-card"]|)
      end

      test "single site won't show neither CTA or view - team setup", %{
        conn: conn,
        user: user
      } do
        new_site(owner: user)

        user |> team_of() |> Plausible.Teams.complete_setup()

        {:ok, _lv, html} = live(conn, "/sites")

        refute element_exists?(html, ~s|[data-test-id="consolidated-view-card-cta"]|)
        refute element_exists?(html, ~s|[data-test-id="consolidated-view-card"]|)
      end

      test "CTA advertises contacting team owner to viewers", %{
        conn: conn,
        user: user
      } do
        new_site(owner: user)
        new_site(owner: user)

        subscribe_to_growth_plan(user)

        team = user |> team_of() |> Plausible.Teams.complete_setup()

        viewer = add_member(team, role: :viewer)

        {:ok, conn: conn} = log_in(%{user: viewer, conn: conn})

        {:ok, _lv, html} = live(conn, "/sites?__team=#{team.identifier}")

        assert element_exists?(html, ~s|[data-test-id="consolidated-view-card-cta"]|)

        assert text_of_element(html, ~s|[data-test-id="consolidated-view-card-cta"]|) =~
                 "Available on Business plans. Contact your team owner to create it."

        refute element_exists?(
                 html,
                 ~s|[data-test-id="consolidated-view-card-cta"] a[href="/billing/choose-plan"]|
               )
      end

      test "CTA can be permanently dismissed, in which case dropdown option to restore it shows up",
           %{conn: conn, user: user} do
        new_site(owner: user)
        new_site(owner: user)

        dismiss_selector = ~s|[phx-click="consolidated-view-cta-dismiss"]|
        cta_selector = ~s|[data-test-id="consolidated-view-card-cta"]|
        restore_selector = ~s|[phx-click="consolidated-view-cta-restore"]|

        subscribe_to_growth_plan(user)

        {:ok, lv, html} = live(conn, "/sites")

        assert element_exists?(html, cta_selector)
        refute element_exists?(html, restore_selector)

        lv
        |> element(dismiss_selector)
        |> render_click()

        html = render(lv)

        refute element_exists?(html, cta_selector)
        assert element_exists?(html, restore_selector)

        {:ok, _lv, html} = live(conn, "/sites")
        refute element_exists?(html, cta_selector)

        lv
        |> element(restore_selector)
        |> render_click()

        html = render(lv)
        assert element_exists?(html, cta_selector)
      end

      test "consolidated view card disappears when searching", %{conn: conn, user: user} do
        new_site(owner: user)
        new_site(owner: user)

        team = user |> team_of() |> Plausible.Teams.complete_setup()
        conn = set_current_team(conn, team)

        {:ok, lv, html} = live(conn, "/sites")

        assert element_exists?(html, ~s|[data-test-id="consolidated-view-card"]|)

        type_into_input(lv, "filter-text", "a")

        html = render(lv)

        refute element_exists?(html, ~s|[data-test-id="consolidated-view-card"]|)
      end

      test "CTA card disappears when searching", %{conn: conn, user: user} do
        new_site(owner: user)
        new_site(owner: user)

        {:ok, lv, html} = live(conn, "/sites")

        assert element_exists?(html, ~s|[data-test-id="consolidated-view-card-cta"]|)

        type_into_input(lv, "filter-text", "a")

        html = render(lv)

        refute element_exists?(html, ~s|[data-test-id="consolidated-view-card-cta"]|)
      end
    end
  end

  describe "pinning" do
    test "renders pin site option when site not pinned", %{conn: conn, user: user} do
      site = new_site(owner: user)

      {:ok, _lv, html} = live(conn, "/sites")

      assert text_of_element(
               html,
               ~s/li[data-domain="#{site.domain}"] a[phx-value-domain]/
             ) == "Pin site"
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

      assert text_of_element(html, button_selector) == "Unpin site"

      html =
        lv
        |> element(button_selector)
        |> render_click()

      assert html =~ "Site unpinned"

      assert text_of_element(html, button_selector) == "Pin site"
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

      assert html =~
               LazyHTML.html_escape("Looks like you've hit the pinned sites limit!")
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
end
