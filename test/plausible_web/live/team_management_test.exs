defmodule PlausibleWeb.Live.TeamMangementTest do
  use PlausibleWeb.ConnCase, async: false
  use Bamboo.Test, shared: true
  use Plausible.Teams.Test

  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  def team_general_path(), do: Routes.settings_path(PlausibleWeb.Endpoint, :team_general)
  @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "

  describe "/settings/team/general" do
    setup [:create_user, :log_in, :create_team, :setup_team]

    test "renders team management section", %{conn: conn} do
      resp =
        conn
        |> get(team_general_path())
        |> html_response(200)
        |> text()

      assert resp =~ "Add, remove or change your team memberships."

      refute element_exists?(resp, ~s|button[phx-click="save-team-layout"]|)
    end

    test "renders existing guests under Guest divider", %{conn: conn, user: user} do
      site = new_site(owner: user)
      add_guest(site, role: :viewer, user: new_user(name: "Mr Guest", email: "guest@example.com"))

      resp =
        conn
        |> get(team_general_path())
        |> html_response(200)

      assert element_exists?(resp, "#guests-hr")

      assert find(resp, "#member-list .member:first-of-type") |> text() =~ "#{user.email}"
      assert find(resp, "#guest-list .guest:first-of-type") |> text() =~ "guest@example.com"
    end

    test "does not render Guest divider when no guests found", %{conn: conn} do
      resp =
        conn
        |> get(team_general_path())
        |> html_response(200)

      refute element_exists?(resp, "#guests-hr")
      refute element_exists?(resp, "#guest-list")
    end
  end

  describe "live" do
    setup [:create_user, :log_in, :create_team, :setup_team]

    test "renders member, immediately delivers invitation", %{conn: conn, user: user, team: team} do
      {lv, html} = get_liveview(conn, with_html?: true)
      member_row1 = find(html, "#member-list .member:nth-of-type(1)") |> text()
      assert member_row1 =~ "#{user.name}"
      assert member_row1 =~ "#{user.email}"
      assert member_row1 =~ "You"

      add_invite(lv, "new@example.com", "admin")

      html = render(lv)

      member_row1 = find(html, "#member-list .member:nth-of-type(1)") |> text()
      assert member_row1 =~ "new@example.com"
      assert member_row1 =~ "Invited User"
      assert member_row1 =~ "Invitation Sent"

      member_row2 = find(html, "#member-list .member:nth-of-type(2)") |> text()
      assert member_row2 =~ "#{user.name}"
      assert member_row2 =~ "#{user.email}"

      assert_email_delivered_with(
        to: [nil: "new@example.com"],
        subject: @subject_prefix <> "You've been invited to \"#{team.name}\" team"
      )
    end

    test "allows updating membership role in place", %{conn: conn, team: team} do
      member2 = add_member(team, role: :admin)
      lv = get_liveview(conn)

      html = render(lv)

      assert text_of_element(html, "#member-list .member:nth-of-type(1) button") == "Owner"
      assert text_of_element(html, "#member-list .member:nth-of-type(2) button") == "Admin"

      change_role(lv, 2, "viewer")
      html = render(lv)

      assert text_of_element(html, "#member-list .member:nth-of-type(2) button") == "Viewer"

      assert_no_emails_delivered()

      assert_team_membership(member2, team, :viewer)
    end

    test "allows updating guest membership so it moves sections", %{
      conn: conn,
      user: user
    } do
      site = new_site(owner: user)
      add_guest(site, role: :viewer, user: new_user(name: "Mr Guest", email: "guest@example.com"))

      lv = get_liveview(conn)

      html = render(lv)

      assert length(find(html, "#member-list .member")) == 1

      assert text_of_element(html, "#guest-list .guest:first-of-type button") == "Guest"

      change_role(lv, 1, "viewer", "#guest-list .guest")
      html = render(lv)

      assert length(find(html, "#member-list .member")) == 2
      refute element_exists?(html, "#guest-list")
    end

    test "fails to save layout with limits breached", %{conn: conn, team: team} do
      lv = get_liveview(conn)
      add_invite(lv, "new1@example.com", "admin")
      add_invite(lv, "new2@example.com", "admin")
      add_invite(lv, "new3@example.com", "admin")
      add_invite(lv, "new4@example.com", "admin")

      assert lv |> render() |> text() =~ "Your account is limited to 3 team members"
      assert Enum.count(Plausible.Teams.Invitations.all(team)) == 3
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

      lv = get_liveview(conn)
      add_invite(lv, "pending@example.com", "admin")

      html = render(lv)

      assert html |> find("#member-list .member") |> Enum.count() == 4
      assert html |> find("#guest-list .guest") |> Enum.count() == 1

      pending = find(html, "#member-list .member:nth-of-type(1)") |> text()
      sent = find(html, "#member-list .member:nth-of-type(2)") |> text()
      owner = find(html, "#member-list .member:nth-of-type(3)") |> text()
      admin = find(html, "#member-list .member:nth-of-type(4)") |> text()

      guest_member = find(html, "#guest-list .guest:first-of-type") |> text()

      assert pending =~ "Invitation Pending"
      assert sent =~ "Invitation Sent"
      assert owner =~ "You"
      assert admin =~ "Team Member"
      assert guest_member =~ "Guest"

      remove_member(lv, 1)
      # next becomes first
      remove_member(lv, 1)
      # last becomes second
      remove_member(lv, 2)

      # remove guest
      remove_member(lv, 1, "#guest-list .guest")

      html = render(lv) |> text()

      refute html =~ "Invitation Pending"
      refute html =~ "Invitation Sent"
      refute html =~ "Team Member"
      refute html =~ "Guest"

      html = render(lv)

      assert html |> find("#member-list .member") |> Enum.count() == 1
      refute element_exists?(html, "#guest-list")

      assert_email_delivered_with(
        to: [nil: member2.email],
        subject: @subject_prefix <> "Your access to \"#{team.name}\" team has been revoked"
      )

      assert_email_delivered_with(
        to: [nil: guest.email],
        subject: @subject_prefix <> "Your access to \"#{team.name}\" team has been revoked"
      )

      assert_no_emails_delivered()
    end
  end

  defp change_role(lv, index, role, main_selector \\ "#member-list .member") do
    lv
    |> element(~s|#{main_selector}:nth-of-type(#{index}) a[phx-value-role="#{role}"]|)
    |> render_click()
  end

  defp remove_member(lv, index, main_selector \\ "#member-list .member") do
    lv
    |> element(~s|#{main_selector}:nth-of-type(#{index}) a[phx-click="remove-member"]|)
    |> render_click()
  end

  defp add_invite(lv, email, role) do
    lv
    |> element(~s|#input-role-picker a[phx-value-role="#{role}"]|)
    |> render_click()

    lv
    |> element("#team-layout-form")
    |> render_submit(%{
      "input-email" => email
    })
  end

  defp get_liveview(conn, opts \\ []) do
    conn = assign(conn, :live_module, PlausibleWeb.Live.TeamManagement)
    {:ok, lv, html} = live(conn, team_general_path())

    if Keyword.get(opts, :with_html?) do
      {lv, html}
    else
      lv
    end
  end
end
