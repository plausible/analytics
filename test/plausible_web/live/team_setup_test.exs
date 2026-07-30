defmodule PlausibleWeb.Live.TeamSetupTest do
  use PlausibleWeb.ConnCase, async: false
  use Bamboo.Test, shared: true

  import Phoenix.LiveViewTest

  alias Plausible.Teams
  alias Plausible.Repo

  @url "/team/setup"
  @installation_url "/example.com/installation?flow=register"
  @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "

  describe "/team/setup - edge cases" do
    setup [:create_user, :log_in]

    test "redirects if there's no implicit team created", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/sites"}}} = live(conn, @url)
    end

    test "redirects to /team/general if team is already set up", %{conn: conn, user: user} do
      {:ok, team} = Teams.get_or_create(user)
      Teams.complete_setup(team)
      conn = set_current_team(conn, team)
      assert {:error, {:redirect, %{to: "/settings/team/general"}}} = live(conn, @url)
    end
  end

  describe "/team/setup - main differences from team management" do
    setup [:create_user, :log_in, :create_team]

    test "renames the team on first render", %{conn: conn, team: team} do
      assert team.name == "My personal sites"
      {:ok, _lv, html} = live(conn, @url)

      assert text_of_attr(html, ~s|input#team-setup-form_name[name="team[name]"]|, "value") ==
               "Jane Smith's team"

      assert Repo.reload!(team).name == "Jane Smith's team"
    end

    test "renames even if team already has non-default name", %{conn: conn, team: team} do
      assert team.name == "My personal sites"
      Repo.update!(Teams.Team.name_changeset(team, %{name: "Foo"}))
      {:ok, _lv, html} = live(conn, @url)

      assert text_of_attr(html, ~s|input#team-setup-form_name[name="team[name]"]|, "value") ==
               "Jane Smith's team"

      assert Repo.reload!(team).name == "Jane Smith's team"
    end

    test "renders the same form as onboarding, plus the members list", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @url)

      assert element_exists?(html, ~s|input#team-setup-form_name[name="team[name]"]|)
      assert element_exists?(html, ~s|input#invite-email-0[name="invites[]"]|)
      assert element_exists?(html, "#member-list")
      assert text_of_element(html, submit_el()) == "Create team"
      assert text_of_element(html, ~s|#team-setup-form a[href="/sites"]|) == "Cancel"
    end

    test "cancelling goes back to where the setup was started from", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @url <> "?return_to=/example.com/settings/people")

      assert text_of_element(
               html,
               ~s|#team-setup-form a[href="/example.com/settings/people"]|
             ) == "Cancel"
    end

    test "cancelling falls back to the site list on a non-local return path", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @url <> "?return_to=" <> URI.encode("//evil.example.com"))

      assert text_of_element(html, ~s|#team-setup-form a[href="/sites"]|) == "Cancel"
    end

    test "changing team name, updates team name in db", %{conn: conn, team: team} do
      {:ok, lv, _html} = live(conn, @url)
      type_into_input(lv, "team[name]", "New Team Name")
      assert Repo.reload!(team).name == "New Team Name"

      _ = render(lv)
    end

    test "setting team name to 'My personal sites' is reserved", %{
      conn: conn,
      team: team,
      user: user
    } do
      {:ok, lv, html} = live(conn, @url)

      assert text_of_attr(html, ~s|input#team-setup-form_name[name="team[name]"]|, "value") ==
               "#{user.name}'s team"

      type_into_input(lv, "team[name]", "Team Name 1")
      _ = render(lv)
      type_into_input(lv, "team[name]", "My personal sites")
      _ = render(lv)
      assert Repo.reload!(team).name == "Team Name 1"
    end

    @tag :ee_only
    test "blurs UI with an upgrade CTA if the subscription team member limit is 0", %{
      conn: conn,
      user: user
    } do
      subscribe_to_starter_plan(user)

      {:ok, _lv, html} = live(conn, @url)

      assert element_exists?(html, "#feature-gate-inner-block-container")
      assert element_exists?(html, "#feature-gate-overlay")
      assert text_of_element(html, "#feature-gate-overlay") =~ "Upgrade to unlock"
    end
  end

  describe "/team/setup - members list" do
    setup [:create_user, :log_in, :create_team]

    test "renders member, enqueues invitation, delivers it", %{
      conn: conn,
      user: user,
      team: team
    } do
      {:ok, lv, html} = live(conn, @url)

      member_row = find(html, "#{member_el()}:nth-of-type(1)") |> text()
      assert member_row =~ user.name
      assert member_row =~ user.email
      assert member_row =~ "You"

      add_invites(lv, [{"new@example.com", "admin"}])
      submit(lv)

      assert_redirect(lv, "/settings/team/general?__team=" <> team.identifier)

      team = Repo.reload!(team)
      assert Teams.setup?(team)

      assert_email_delivered_with(
        to: [nil: "new@example.com"],
        subject: @subject_prefix <> "You've been invited to \"#{team.name}\" team"
      )

      assert [invitation] = Repo.all(Plausible.Teams.Invitation)
      assert invitation.role == :admin
    end

    test "allows updating a sent invitation role in place", %{
      conn: conn,
      user: user,
      team: team
    } do
      invite_member(team, "sent@example.com", inviter: user, role: :admin)

      {:ok, lv, html} = live(conn, @url)

      assert text_of_element(html, "#{member_el()}:nth-of-type(1) button") == "Admin"

      change_role(lv, 1, "viewer")
      html = render(lv)

      assert text_of_element(html, "#{member_el()}:nth-of-type(1) button") == "Viewer"

      submit(lv)

      assert [invitation] = Repo.all(Plausible.Teams.Invitation)
      assert invitation.role == :viewer
    end

    test "allows updating membership role in place", %{conn: conn, team: team} do
      member2 = add_member(team, role: :admin)

      {:ok, lv, html} = live(conn, @url)

      assert text_of_element(html, "#{member_el()}:nth-of-type(1) button") == "Owner"
      assert text_of_element(html, "#{member_el()}:nth-of-type(2) button") == "Admin"

      change_role(lv, 2, "viewer")
      html = render(lv)

      assert text_of_element(html, "#{member_el()}:nth-of-type(2) button") == "Viewer"

      submit(lv)

      assert_no_emails_delivered()
      assert_team_membership(member2, team, :viewer)
    end

    test "allows updating guest membership so it moves sections and sends out promotion e-mail",
         %{
           conn: conn,
           user: user,
           team: team
         } do
      site = new_site(owner: user)
      add_guest(site, role: :viewer, user: new_user(name: "Mr Guest", email: "guest@example.com"))

      {:ok, lv, html} = live(conn, @url)

      assert elem_count(html, member_el()) == 1
      assert text_of_element(html, "#{guest_el()}:first-of-type button") == "Guest"

      type_into_input(lv, "team[name]", "A-Team!")
      assert Repo.reload!(team).name == "A-Team!"

      change_role(lv, 1, "viewer", guest_el())
      html = render(lv)

      assert elem_count(html, member_el()) == 2
      refute element_exists?(html, "#guest-list")

      submit(lv)

      assert_email_delivered_with(
        to: [nil: "guest@example.com"],
        subject: @subject_prefix <> "Welcome to \"A-Team!\" team"
      )
    end

    test "all options are disabled for the sole owner", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @url)

      assert Enum.empty?(find(html, "#{member_el()} a"))
    end

    test "in case of >1 owner, the one owner limit is still enforced", %{conn: conn, team: team} do
      _other_owner = add_member(team, role: :owner)

      {:ok, lv, html} = live(conn, @url)

      refute Enum.empty?(find(html, "#{member_el()} a"))

      change_role(lv, 1, "viewer")

      html = lv |> render()

      assert element_exists?(html, "#{member_el()}:nth-of-type(1) a")
      refute element_exists?(html, "#{member_el()}:nth-of-type(2) a")
    end

    test "allows removing any type of entry", %{
      conn: conn,
      user: user,
      team: team
    } do
      member2 = add_member(team, role: :admin)
      _invitation = invite_member(team, "sent@example.com", inviter: user, role: :viewer)

      site = new_site(owner: user)

      guest =
        add_guest(site,
          role: :viewer,
          user: new_user(name: "Mr Guest", email: "guest@example.com")
        )

      {:ok, lv, html} = live(conn, @url)

      assert elem_count(html, member_el()) == 3
      assert elem_count(html, guest_el()) == 1

      sent = find(html, "#{member_el()}:nth-of-type(1)") |> text()
      owner = find(html, "#{member_el()}:nth-of-type(2)") |> text()
      admin = find(html, "#{member_el()}:nth-of-type(3)") |> text()
      guest_member = find(html, "#{guest_el()}:first-of-type") |> text()

      assert sent =~ "Invitation sent"
      assert owner =~ "You"
      assert admin != ""
      assert guest_member =~ "Guest"

      remove_member(lv, "sent@example.com")
      remove_member(lv, member2.email)
      remove_member(lv, guest.email)

      html = render(lv) |> text()

      refute html =~ "Invitation sent"
      refute html =~ "Guest"

      submit(lv)

      team = Repo.reload!(team)

      assert_email_delivered_with(
        to: [nil: guest.email],
        subject: @subject_prefix <> "Your access to \"#{team.name}\" team has been revoked"
      )

      assert_email_delivered_with(
        to: [nil: member2.email],
        subject: @subject_prefix <> "Your access to \"#{team.name}\" team has been revoked"
      )

      assert_no_emails_delivered()
    end

    test "inviting a member enqueued for removal brings them back", %{conn: conn, team: team} do
      member2 = add_member(team, role: :editor, user: new_user(email: "another@example.com"))

      {:ok, lv, _html} = live(conn, @url)

      remove_member(lv, member2.email)

      add_invites(lv, [{"another@example.com", "viewer"}])
      submit(lv)

      assert_no_emails_delivered()
      assert_team_membership(member2, team, :viewer)
    end

    @tag :ee_only
    test "blocks inviting more members than the plan allows", %{conn: conn, team: team} do
      insert(:growth_subscription, team: team)

      {:ok, lv, html} = live(conn, @url)

      refute attr_defined?(html, "#add-invite-row", "disabled")
      refute attr_defined?(html, submit_el(), "disabled")

      add_invites(lv, [
        {"new1@example.com", "viewer"},
        {"new2@example.com", "viewer"},
        {"new3@example.com", "viewer"}
      ])

      html = render(lv)

      assert attr_defined?(html, "#add-invite-row", "disabled")
      assert attr_defined?(html, submit_el(), "disabled")

      assert text_of_element(html, ~s/[data-test="limit-exceeded-notice"]/) =~
               "This account is limited to 3 members"
    end
  end

  describe "/team/setup - register flow" do
    setup [:create_user, :log_in, :create_team]

    test "redirects to installation if team is already set up", %{conn: conn, team: team} do
      Teams.complete_setup(team)
      conn = set_current_team(conn, team)

      assert {:error, {:redirect, %{to: to}}} = live(conn, onboarding_url("example.com"))
      assert to == @installation_url
    end

    for {domain, expected_name} <- [
          {"plausible.io", "Plausible"},
          {"blog.plausible.io", "Plausible"},
          {"example.co.uk", "Example"},
          {"my-shop.com", "My Shop"}
        ] do
      test "prefills the team name from #{domain}", %{conn: conn, team: team} do
        {:ok, _lv, html} = live(conn, onboarding_url(unquote(domain)))

        assert text_of_attr(html, ~s|input#team-setup-form_name|, "value") ==
                 unquote(expected_name)

        assert Repo.reload!(team).name == unquote(expected_name)
      end
    end

    test "falls back to the personal team name without a domain", %{conn: conn, user: user} do
      {:ok, _lv, html} = live(conn, @url <> "?flow=register")

      assert text_of_attr(html, ~s|input#team-setup-form_name|, "value") ==
               "#{user.name}'s team"
    end

    test "skipping without a site goes back to the site list", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @url <> "?flow=register")

      assert text_of_element(html, ~s|#team-setup-form a[href="/sites"]|) == "Skip"
    end

    test "renders one invite row, skipping the members list", %{conn: conn} do
      {:ok, _lv, html} = live(conn, onboarding_url("example.com"))

      assert element_exists?(html, ~s|input#invite-email-0[name="invites[]"]|)
      refute element_exists?(html, ~s|input#invite-email-1|)
      refute element_exists?(html, "#member-list")
      assert text_of_element(html, "#invite-role-0 button") == "Viewer"
      assert text_of_element(html, ~s|a[href="#{@installation_url}"]|) == "Skip"
    end

    test "adds invite rows, keeping typed emails and picked roles", %{conn: conn} do
      {:ok, lv, _html} = live(conn, onboarding_url("example.com"))

      lv |> element("#add-invite-row") |> render_click()
      fill_invites(lv, ["first@example.com", "second@example.com"])
      pick_role(lv, 1, "admin")

      html = render(lv)

      assert text_of_attr(html, "input#invite-email-0", "value") == "first@example.com"
      assert text_of_attr(html, "input#invite-email-1", "value") == "second@example.com"
      assert text_of_element(html, "#invite-role-0 button") == "Viewer"
      assert text_of_element(html, "#invite-role-1 button") == "Admin"
    end

    test "creating the team sends the invitations and completes setup", %{
      conn: conn,
      team: team
    } do
      {:ok, lv, _html} = live(conn, onboarding_url("example.com"))

      lv |> element("#add-invite-row") |> render_click()
      fill_invites(lv, ["new@example.com", ""])
      pick_role(lv, 0, "admin")

      create_team(lv, "My Team")

      assert_redirect(lv, installation_url(team))

      team = Repo.reload!(team)
      assert team.name == "My Team"
      assert Teams.setup?(team)

      assert_email_delivered_with(
        to: [nil: "new@example.com"],
        subject: @subject_prefix <> "You've been invited to \"My Team\" team"
      )

      assert [invitation] = Repo.all(Plausible.Teams.Invitation)
      assert invitation.email == "new@example.com"
      assert invitation.role == :admin
    end

    test "creating the team without invitations completes setup", %{conn: conn, team: team} do
      {:ok, lv, _html} = live(conn, onboarding_url("example.com"))

      create_team(lv, "My Team")

      # the new team becomes the current one on the next request
      assert_redirect(lv, installation_url(team))
      assert Teams.setup?(Repo.reload!(team))
      assert_no_emails_delivered()
    end

    test "rejects invalid and duplicate emails inline", %{conn: conn, team: team} do
      {:ok, lv, _html} = live(conn, onboarding_url("example.com"))

      lv |> element("#add-invite-row") |> render_click()
      lv |> element("#add-invite-row") |> render_click()
      fill_invites(lv, ["nope", "new@example.com", "new@example.com"])

      html = create_team(lv, "My Team")

      assert html =~ "Please enter a valid email address"
      assert html =~ "This email is already added"

      refute Teams.setup?(Repo.reload!(team))
      assert_no_emails_delivered()
    end

    test "skipping goes to installation without completing setup", %{conn: conn, team: team} do
      {:ok, _lv, html} = live(conn, onboarding_url("example.com"))

      assert text_of_element(html, ~s|a[href="#{@installation_url}"]|) == "Skip"

      refute Teams.setup?(Repo.reload!(team))
      assert_no_emails_delivered()
    end
  end

  describe "/team/setup - register flow, site skipped" do
    setup [:create_user, :log_in]

    test "creates the team implicitly for a user who has none yet", %{conn: conn, user: user} do
      assert {:error, :no_team} = Teams.get_by_owner(user)

      {:ok, lv, html} = live(conn, @url <> "?flow=register")

      assert text_of_attr(html, ~s|input#team-setup-form_name|, "value") ==
               "#{user.name}'s team"

      create_team(lv, "My Team")

      assert {:ok, team} = Teams.get_by_owner(user)
      assert_redirect(lv, "/sites?__team=" <> team.identifier)

      assert team.name == "My Team"
      assert Teams.setup?(team)
    end
  end

  defp onboarding_url(domain) do
    @url <> "?flow=register&domain=#{domain}"
  end

  defp installation_url(team) do
    @installation_url <> "&__team=#{team.identifier}"
  end

  defp fill_invites(lv, emails) do
    lv
    |> element("form#team-setup-form")
    |> render_change(%{"invites" => emails})
  end

  defp pick_role(lv, index, role) do
    lv
    |> element(~s|#invite-role-#{index} a[phx-value-role="#{role}"]|)
    |> render_click()
  end

  defp create_team(lv, name) do
    lv
    |> element("form#team-setup-form")
    |> render_submit(%{"team" => %{"name" => name}})
  end

  defp submit(lv) do
    lv
    |> element("form#team-setup-form")
    |> render_submit()
  end

  defp type_into_input(lv, id, text) do
    lv
    |> element("form#team-setup-form")
    |> render_change(%{id => text})
  end

  defp add_invites(lv, invites) do
    for _ <- Enum.drop(invites, 1) do
      lv |> element("#add-invite-row") |> render_click()
    end

    fill_invites(lv, Enum.map(invites, fn {email, _role} -> email end))

    for {{_email, role}, index} <- Enum.with_index(invites) do
      pick_role(lv, index, role)
    end

    render(lv)
  end

  defp change_role(lv, index, role, main_selector \\ member_el()) do
    lv
    |> element(~s|#{main_selector}:nth-of-type(#{index}) a[phx-value-role="#{role}"]|)
    |> render_click()
  end

  defp remove_member(lv, email) do
    lv
    |> element(~s|#member-row-#{:erlang.phash2(email)} a[phx-click="remove-member"]|)
    |> render_click()
  end

  defp submit_el() do
    ~s|#team-setup-form button[type="submit"]|
  end

  defp member_el() do
    ~s|#member-list div[data-test-kind="member"]|
  end

  defp guest_el() do
    ~s|#guest-list div[data-test-kind="guest"]|
  end
end
