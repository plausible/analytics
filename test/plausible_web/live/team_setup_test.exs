defmodule PlausibleWeb.Live.TeamSetupTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Teams.Test
  use Bamboo.Test, shared: true

  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  alias Plausible.Teams
  alias Plausible.Repo

  @url "/team/setup"
  @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "

  describe "/team/setup - edge cases" do
    setup [:create_user, :log_in]

    test "redirects if there's no implicit team created", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/sites"}}} = live(conn, @url)
    end

    test "redirects to /team/general if team is already set up", %{conn: conn, user: user} do
      {:ok, team} = Teams.get_or_create(user)
      team |> Teams.Team.setup_changeset() |> Repo.update!()
      assert {:error, {:redirect, %{to: "/settings/team/general"}}} = live(conn, @url)
    end

    test "does not redirect to /team/general if dev mode", %{conn: conn, user: user} do
      {:ok, team} = Teams.get_or_create(user)
      team |> Teams.Team.setup_changeset() |> Repo.update!()
      assert {:ok, lv, _} = live(conn, @url <> "?dev=1")
      _ = render(lv)
    end
  end

  describe "/team/setup - main differences from team management" do
    setup [:create_user, :log_in, :create_team]

    test "renames the team on first render", %{conn: conn, team: team} do
      assert team.name == "My Personal Sites"
      {:ok, _lv, html} = live(conn, @url)

      assert text_of_attr(html, ~s|input#update-team-form_name[name="team[name]"]|, "value") ==
               "Jane Smith's Team"

      assert Repo.reload!(team).name == "Jane Smith's Team"
    end

    test "renames even if team already has non-default name", %{conn: conn, team: team} do
      assert team.name == "My Personal Sites"
      Repo.update!(Teams.Team.name_changeset(team, %{name: "Foo"}))
      {:ok, _lv, html} = live(conn, @url)

      assert text_of_attr(html, ~s|input#update-team-form_name[name="team[name]"]|, "value") ==
               "Jane Smith's Team"

      assert Repo.reload!(team).name == "Jane Smith's Team"
    end

    test "renders form", %{conn: conn} do
      {:ok, lv, html} = live(conn, @url)
      assert element_exists?(html, ~s|input#update-team-form_name[name="team[name]"]|)
      assert element_exists?(html, ~s|button[phx-click="save-team-layout"]|)

      _ = render(lv)
    end

    test "changing team name, updates team name in db", %{conn: conn, team: team} do
      {:ok, lv, _html} = live(conn, @url)
      type_into_input(lv, "team[name]", "New Team Name")
      assert Repo.reload!(team).name == "New Team Name"

      _ = render(lv)
    end

    test "setting team name to 'My Personal Sites' is reserved", %{
      conn: conn,
      team: team,
      user: user
    } do
      {:ok, lv, html} = live(conn, @url)

      assert text_of_attr(html, ~s|input#update-team-form_name[name="team[name]"]|, "value") ==
               "#{user.name}'s Team"

      type_into_input(lv, "team[name]", "Team Name 1")
      _ = render(lv)
      type_into_input(lv, "team[name]", "My Personal Sites")
      _ = render(lv)
      assert Repo.reload!(team).name == "Team Name 1"
    end
  end

  describe "/team/setup - full integration" do
    setup [:create_user, :log_in, :create_team]

    test "renders member, enqueues invitation, delivers it", %{conn: conn, user: user, team: team} do
      {lv, html} = get_child_lv(conn, with_html?: true)
      member_row1 = find(html, "#{member_el()}:nth-of-type(1)") |> text()
      assert member_row1 =~ "#{user.name}"
      assert member_row1 =~ "#{user.email}"
      assert member_row1 =~ "You"

      add_invite(lv, "new@example.com", "admin")

      html = render(lv)

      member_row1 = find(html, "#{member_el()}:nth-of-type(1)") |> text()
      assert member_row1 =~ "new@example.com"
      assert member_row1 =~ "Invited User"
      assert member_row1 =~ "Invitation Pending"

      member_row2 = find(html, "#{member_el()}:nth-of-type(2)") |> text()
      assert member_row2 =~ "#{user.name}"
      assert member_row2 =~ "#{user.email}"

      save_layout(lv)

      assert_redirect(lv, "/settings/team/general")

      team = Repo.reload!(team)

      assert_email_delivered_with(
        to: [nil: "new@example.com"],
        subject: @subject_prefix <> "You've been invited to \"#{team.name}\" team"
      )
    end

    test "allows updating pending invitation role in place", %{conn: conn, team: team} do
      lv = get_child_lv(conn)
      add_invite(lv, "new@example.com", "admin")

      html = render(lv)

      assert text_of_element(html, "#{member_el()}:nth-of-type(1) button") == "Admin"
      assert text_of_element(html, "#{member_el()}:nth-of-type(2) button") == "Owner"

      change_role(lv, 1, "viewer")
      html = render(lv)

      assert text_of_element(html, "#{member_el()}:nth-of-type(1) button") == "Viewer"

      save_layout(lv)

      team = Repo.reload!(team)

      assert_email_delivered_with(
        to: [nil: "new@example.com"],
        subject: @subject_prefix <> "You've been invited to \"#{team.name}\" team"
      )
    end

    test "allows updating membership role in place", %{conn: conn, team: team} do
      member2 = add_member(team, role: :admin)
      {lv, html} = get_child_lv(conn, with_html?: true)

      assert text_of_element(html, "#{member_el()}:nth-of-type(1) button") == "Owner"
      assert text_of_element(html, "#{member_el()}:nth-of-type(2) button") == "Admin"

      change_role(lv, 2, "viewer")
      html = render(lv)

      assert text_of_element(html, "#{member_el()}:nth-of-type(2) button") == "Viewer"

      save_layout(lv)

      assert_no_emails_delivered()

      assert_team_membership(member2, team, :viewer)
    end

    test "allows updating guest membership so it moves sections", %{
      conn: conn,
      user: user
    } do
      site = new_site(owner: user)
      add_guest(site, role: :viewer, user: new_user(name: "Mr Guest", email: "guest@example.com"))

      lv = get_child_lv(conn)

      html = render(lv)

      assert length(find(html, member_el())) == 1

      assert text_of_element(html, "#{guest_el()}:first-of-type button") == "Guest"

      change_role(lv, 1, "viewer", guest_el())
      html = render(lv)

      assert length(find(html, member_el())) == 2
      refute element_exists?(html, "#guest-list")
    end

    test "fails to save layout with limits breached", %{conn: conn} do
      lv = get_child_lv(conn)
      add_invite(lv, "new1@example.com", "admin")
      add_invite(lv, "new2@example.com", "admin")
      add_invite(lv, "new3@example.com", "admin")
      add_invite(lv, "new4@example.com", "admin")

      refute lv |> render() |> text() =~ "Your account is limited to 3 team members"

      save_layout(lv)

      assert lv |> render() |> text() =~ "Your account is limited to 3 team members"
    end

    test "all options are disabled for the sole owner", %{conn: conn} do
      lv = get_child_lv(conn)

      options =
        lv
        |> render()
        |> find("#{member_el()} a")

      assert Enum.empty?(options)
    end

    test "in case of >1 owner, the one owner limit is still enforced", %{conn: conn, team: team} do
      _other_owner = add_member(team, role: :owner)
      lv = get_child_lv(conn)

      options =
        lv
        |> render()
        |> find("#{member_el()} a")

      refute Enum.empty?(options)

      change_role(lv, 1, "viewer")

      html = lv |> render()

      assert [_ | _] = find(html, "#{member_el()}:nth-of-type(1) a")
      assert find(html, "#{member_el()}:nth-of-type(2) a") == []
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

      lv = get_child_lv(conn)
      add_invite(lv, "pending@example.com", "admin")

      html = render(lv)

      assert html |> find(member_el()) |> Enum.count() == 4
      assert html |> find(guest_el()) |> Enum.count() == 1

      pending = find(html, "#{member_el()}:nth-of-type(1)") |> text()
      sent = find(html, "#{member_el()}:nth-of-type(2)") |> text()
      owner = find(html, "#{member_el()}:nth-of-type(3)") |> text()
      admin = find(html, "#{member_el()}:nth-of-type(4)") |> text()

      guest_member = find(html, "#{guest_el()}:first-of-type") |> text()

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
      remove_member(lv, 1, guest_el())

      html = render(lv) |> text()

      refute html =~ "Invitation Pending"
      refute html =~ "Invitation Sent"
      refute html =~ "Team Member"
      refute html =~ "Guest"

      save_layout(lv)

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

    test "respawns membersip enqueued for deletion", %{
      conn: conn,
      team: team
    } do
      member2 = add_member(team, role: :editor, user: new_user(email: "another@example.com"))

      lv = get_child_lv(conn)

      remove_member(lv, 1)

      add_invite(lv, "another@example.com", "viewer")

      html = render(lv)

      assert find(html, "#{member_el()}:nth-of-type(1)") |> text() =~ "Team Member"
      assert find(html, "#{member_el()}:nth-of-type(2)") |> text() =~ "You"

      save_layout(lv)

      assert_no_emails_delivered()
      assert_team_membership(member2, team, :viewer)
    end
  end

  defp type_into_input(lv, id, text) do
    lv
    |> element("form#update-team-form")
    |> render_change(%{id => text})
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

  defp save_layout(lv) do
    lv
    |> element("button#save-layout")
    |> render_click()
  end

  defp change_role(lv, index, role, main_selector \\ member_el()) do
    lv
    |> element(~s|#{main_selector}:nth-of-type(#{index}) a[phx-value-role="#{role}"]|)
    |> render_click()
  end

  defp get_child_lv(conn, opts \\ []) do
    {:ok, lv, _} = live(conn, @url)
    assert lv = find_live_child(lv, "team-management-setup")

    if Keyword.get(opts, :with_html?) do
      {lv, render(lv)}
    else
      lv
    end
  end

  defp remove_member(lv, index, main_selector \\ member_el()) do
    lv
    |> element(~s|#{main_selector}:nth-of-type(#{index}) a[phx-click="remove-member"]|)
    |> render_click()
  end

  defp member_el() do
    ~s|#member-list div[data-test-kind="member"]|
  end

  defp guest_el() do
    ~s|#guest-list div[data-test-kind="guest"]|
  end
end
