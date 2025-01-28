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
    end
  end

  describe "live" do
    setup [:create_user, :log_in, :create_team, :setup_team]

    test "renders member, enqueues invitation, delivers it", %{conn: conn, user: user, team: team} do
      {lv, html} = get_liveview(conn, with_html?: true)
      member_row1 = find(html, ".member:nth-of-type(1)") |> text()
      assert member_row1 =~ "#{user.name}"
      assert member_row1 =~ "#{user.email}"
      assert member_row1 =~ "You"

      refute save_layout_active?(lv)

      add_invite(lv, "new@example.com", "admin")

      html = render(lv)

      assert save_layout_active?(lv)

      member_row1 = find(html, ".member:nth-of-type(1)") |> text()
      assert member_row1 =~ "new@example.com"
      assert member_row1 =~ "Invited User"
      assert member_row1 =~ "Invitation Pending"

      member_row2 = find(html, ".member:nth-of-type(2)") |> text()
      assert member_row2 =~ "#{user.name}"
      assert member_row2 =~ "#{user.email}"

      save_layout(lv)

      assert lv |> render() |> find(".member:nth-of-type(1)") |> text() =~ "Invitation Sent"

      assert_email_delivered_with(
        to: [nil: "new@example.com"],
        subject: @subject_prefix <> "You've been invited to \"#{team.name}\" team"
      )
    end

    test "allows updating pending invitation role in place", %{conn: conn, team: team} do
      lv = get_liveview(conn)
      add_invite(lv, "new@example.com", "admin")

      html = render(lv)

      assert text_of_element(html, ".member:nth-of-type(1) button") == "Admin"
      assert text_of_element(html, ".member:nth-of-type(2) button") == "Owner"

      change_role(lv, 1, "viewer")
      html = render(lv)

      assert text_of_element(html, ".member:nth-of-type(1) button") == "Viewer"

      save_layout(lv)

      assert_email_delivered_with(
        to: [nil: "new@example.com"],
        subject: @subject_prefix <> "You've been invited to \"#{team.name}\" team"
      )
    end

    test "allows updating membership role in place", %{conn: conn, team: team} do
      member2 = add_member(team, role: :admin)
      lv = get_liveview(conn)

      html = render(lv)

      assert text_of_element(html, ".member:nth-of-type(1) button") == "Owner"
      assert text_of_element(html, ".member:nth-of-type(2) button") == "Admin"

      change_role(lv, 2, "viewer")
      html = render(lv)

      assert text_of_element(html, ".member:nth-of-type(2) button") == "Viewer"

      save_layout(lv)

      assert_no_emails_delivered()

      assert_team_membership(member2, team, :viewer)
    end

    test "fails to save layout with limits breached", %{conn: conn} do
      lv = get_liveview(conn)
      add_invite(lv, "new1@example.com", "admin")
      add_invite(lv, "new2@example.com", "admin")
      add_invite(lv, "new3@example.com", "admin")
      add_invite(lv, "new4@example.com", "admin")

      save_layout(lv)

      assert lv |> render() |> text() =~ "Your account is limited to 3 team members"
    end

    test "allows removing memberships and any kind of invitation", %{
      conn: conn,
      user: user,
      team: team
    } do
      member2 = add_member(team, role: :admin)
      _invitation = invite_member(team, "sent@example.com", inviter: user, role: :viewer)

      lv = get_liveview(conn)
      add_invite(lv, "pending@example.com", "admin")

      html = render(lv)

      assert html |> find(".member") |> Enum.count() == 4

      pending = find(html, ".member:nth-of-type(1)") |> text()
      sent = find(html, ".member:nth-of-type(2)") |> text()
      owner = find(html, ".member:nth-of-type(3)") |> text()
      admin = find(html, ".member:nth-of-type(4)") |> text()

      assert pending =~ "Invitation Pending"
      assert sent =~ "Invitation Sent"
      assert owner =~ "You"
      assert admin =~ "Team Member"

      remove_member(lv, 1)
      # next becomes first
      remove_member(lv, 1)
      # last becomes second
      remove_member(lv, 2)

      html = render(lv) |> text()

      refute html =~ "Invitation Pending"
      refute html =~ "Invitation Sent"
      refute html =~ "Team Member"

      save_layout(lv)
      html = render(lv)

      assert html |> find(".member") |> Enum.count() == 1

      assert_email_delivered_with(
        to: [nil: member2.email],
        subject: @subject_prefix <> "Your access to \"#{team.name}\" team has been revoked"
      )

      assert_no_emails_delivered()
    end
  end

  defp save_layout(lv) do
    lv
    |> element("button#save-layout")
    |> render_click()
  end

  defp save_layout_active?(lv) do
    lv
    |> render()
    |> find("button#save-layout")
    |> text_of_attr("disabled") == ""
  end

  defp change_role(lv, index, role) do
    lv
    |> element(~s|.member:nth-of-type(#{index}) a[phx-value-role="#{role}"]|)
    |> render_click()
  end

  defp remove_member(lv, index) do
    lv
    |> element(~s|.member:nth-of-type(#{index}) a[phx-click="remove-member"]|)
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
