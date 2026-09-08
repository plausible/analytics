defmodule PlausibleWeb.Live.TeamSetupTest do
  use PlausibleWeb.ConnCase, async: false
  use Bamboo.Test, shared: true

  import Phoenix.LiveViewTest

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
      Teams.complete_setup(team)
      conn = set_current_team(conn, team)
      assert {:error, {:redirect, %{to: "/settings/team/general"}}} = live(conn, @url)
    end
  end

  describe "/team/setup - suggested team name" do
    test "shortens a long user name to fit the limit", %{conn: conn} do
      user = new_user(name: String.duplicate("a", 55))
      {:ok, conn: conn} = log_in(%{user: user, conn: conn})
      {:ok, team} = Teams.get_or_create(user)

      {:ok, _lv, html} = live(conn, @url)

      expected = String.duplicate("a", 43) <> "'s team"

      assert text_of_attr(html, ~s|input#update-team-form_name[name="team[name]"]|, "value") ==
               expected

      assert Repo.reload!(team).name == expected
    end

    test "falls back to a generic name when the user name carries a URL scheme", %{conn: conn} do
      user = new_user(name: "Cheap meds https://spam.example.com")
      {:ok, conn: conn} = log_in(%{user: user, conn: conn})
      {:ok, team} = Teams.get_or_create(user)

      {:ok, _lv, html} = live(conn, @url)

      assert text_of_attr(html, ~s|input#update-team-form_name[name="team[name]"]|, "value") ==
               "My team"

      assert Repo.reload!(team).name == "My team"
    end

    test "falls back to a generic name when shortening overflows the column", %{conn: conn} do
      user = new_user(name: String.duplicate("👨‍👩‍👧‍👦", 36))
      {:ok, conn: conn} = log_in(%{user: user, conn: conn})
      {:ok, team} = Teams.get_or_create(user)

      {:ok, _lv, html} = live(conn, @url)

      assert text_of_attr(html, ~s|input#update-team-form_name[name="team[name]"]|, "value") ==
               "My team"

      assert Repo.reload!(team).name == "My team"
    end
  end

  describe "/team/setup - team name" do
    setup [:create_user, :log_in, :create_team]

    test "renames the team on first render", %{conn: conn, team: team} do
      assert team.name == "My personal sites"
      {:ok, _lv, html} = live(conn, @url)

      assert text_of_attr(html, ~s|input#update-team-form_name[name="team[name]"]|, "value") ==
               "Jane Smith's team"

      assert Repo.reload!(team).name == "Jane Smith's team"
    end

    test "renames even if team already has non-default name", %{conn: conn, team: team} do
      assert team.name == "My personal sites"
      Repo.update!(Teams.Team.name_changeset(team, %{name: "Foo"}))
      {:ok, _lv, html} = live(conn, @url)

      assert text_of_attr(html, ~s|input#update-team-form_name[name="team[name]"]|, "value") ==
               "Jane Smith's team"

      assert Repo.reload!(team).name == "Jane Smith's team"
    end

    test "renders form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @url)
      assert element_exists?(html, ~s|input#update-team-form_name[name="team[name]"]|)
      assert element_exists?(html, "#create-team-submit")
      assert elem_count(html, row_el()) == 1
    end

    test "changing team name, updates team name in db", %{conn: conn, team: team} do
      {:ok, lv, _html} = live(conn, @url)
      type_into_input(lv, "team[name]", "New Team Name")
      assert Repo.reload!(team).name == "New Team Name"
    end

    test "setting team name to 'My personal sites' is reserved", %{
      conn: conn,
      team: team,
      user: user
    } do
      {:ok, lv, html} = live(conn, @url)

      assert text_of_attr(html, ~s|input#update-team-form_name[name="team[name]"]|, "value") ==
               "#{user.name}'s team"

      type_into_input(lv, "team[name]", "Team Name 1")
      type_into_input(lv, "team[name]", "My personal sites")
      assert Repo.reload!(team).name == "Team Name 1"
    end

    test "reserved name is rejected on the very first edit", %{
      conn: conn,
      team: team,
      user: user
    } do
      {:ok, lv, _html} = live(conn, @url)

      type_into_input(lv, "team[name]", "My personal sites")

      assert render(lv) =~ "is reserved"
      assert Repo.reload!(team).name == "#{user.name}'s team"
    end

    test "setting team name containing a URL is rejected", %{conn: conn, team: team} do
      {:ok, lv, _html} = live(conn, @url)

      type_into_input(lv, "team[name]", "Team Name 1")
      _ = render(lv)

      type_into_input(lv, "team[name]", "Cheap meds at https://spam.example.com")

      assert render(lv) =~ "cannot contain a URL"
      assert element_exists?(render(lv), "#create-team-submit[disabled]")
      assert Repo.reload!(team).name == "Team Name 1"
    end

    test "setting team name longer than the limit is rejected", %{conn: conn, team: team} do
      {:ok, lv, _html} = live(conn, @url)

      type_into_input(lv, "team[name]", "Team Name 1")
      _ = render(lv)

      type_into_input(lv, "team[name]", String.duplicate("a", 51))

      assert render(lv) =~ "should be at most 50 character(s)"
      assert element_exists?(render(lv), "#create-team-submit[disabled]")
      assert Repo.reload!(team).name == "Team Name 1"
    end

    test "creating the team is blocked while the name is rejected", %{conn: conn, team: team} do
      {:ok, lv, html} = live(conn, @url)

      refute element_exists?(html, "#create-team-submit[disabled]")

      type_into_input(lv, "team[name]", "My personal sites")

      assert render(lv) =~ "is reserved"
      assert element_exists?(render(lv), "#create-team-submit[disabled]")

      # the server refuses as well, not just the disabled button
      assert render_click(lv, "create-team", %{}) =~ "Please fix the team name first"

      refute Repo.reload!(team).setup_complete
    end

    test "creating the team goes through once the name is accepted", %{conn: conn, team: team} do
      {:ok, lv, _html} = live(conn, @url)

      type_into_input(lv, "team[name]", "My personal sites")
      type_into_input(lv, "team[name]", "Fixed Team Name")

      submit_form(lv)

      assert_redirect(lv, "/settings/team/general?__team=" <> team.identifier)

      team = Repo.reload!(team)
      assert team.setup_complete
      assert team.name == "Fixed Team Name"
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

  describe "/team/setup - adding members" do
    setup [:create_user, :log_in, :create_team]

    test "starts out with a single empty row", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @url)
      assert elem_count(html, row_el()) == 1
    end

    test "add-row appends a row, remove-row removes it", %{conn: conn} do
      {:ok, lv, html} = live(conn, @url)
      assert elem_count(html, row_el()) == 1

      html = add_row(lv)
      assert elem_count(html, row_el()) == 2

      [row_id, _] = row_ids(html)
      html = remove_row(lv, row_id)
      assert elem_count(html, row_el()) == 1
    end

    test "creating the team sends out an invitation for a filled row with the selected role", %{
      conn: conn,
      team: team
    } do
      {:ok, lv, html} = live(conn, @url)
      [row_id] = row_ids(html)

      fill_row(lv, row_id, "new@example.com")
      select_role(lv, row_id, "admin")

      submit_form(lv)

      assert_redirect(lv, "/settings/team/general?__team=" <> team.identifier)

      team = Repo.reload!(team)
      assert team.setup_complete

      assert_email_delivered_with(
        to: [nil: "new@example.com"],
        subject: @subject_prefix <> "You've been invited to \"#{team.name}\" team"
      )

      assert [invitation] = Teams.Invitations.pending_team_invitations_for(team)
      assert invitation.email == "new@example.com"
      assert invitation.role == :admin
    end

    test "blank rows are ignored on submit", %{conn: conn, team: team} do
      {:ok, lv, html} = live(conn, @url)
      [empty_row_id] = row_ids(html)

      html = add_row(lv)
      [^empty_row_id, filled_row_id] = row_ids(html)
      fill_row(lv, filled_row_id, "second@example.com")

      submit_form(lv)

      assert_redirect(lv, "/settings/team/general?__team=" <> team.identifier)

      team = Repo.reload!(team)
      assert [invitation] = Teams.Invitations.pending_team_invitations_for(team)
      assert invitation.email == "second@example.com"
    end

    test "rejects invalid e-mails", %{conn: conn, team: team} do
      {:ok, lv, html} = live(conn, @url)
      [row_id] = row_ids(html)

      fill_row(lv, row_id, "not-an-email")

      assert submit_form(lv) =~ "Make sure all e-mails are valid"
      refute Repo.reload!(team).setup_complete
    end

    test "rejects duplicate e-mails across rows", %{conn: conn, team: team} do
      {:ok, lv, html} = live(conn, @url)
      [row_id] = row_ids(html)
      html = add_row(lv)
      [^row_id, row_id2] = row_ids(html)

      fill_row(lv, row_id, "dup@example.com")
      fill_row(lv, row_id2, "dup@example.com")

      assert submit_form(lv) =~ "Make sure e-mails are unique"
      refute Repo.reload!(team).setup_complete
    end

    @tag :ee_only
    test "fails to create the team when the plan's member limit is breached", %{
      conn: conn,
      team: team
    } do
      insert(:growth_subscription, team: team)

      {:ok, lv, html} = live(conn, @url)
      [row_id] = row_ids(html)
      fill_row(lv, row_id, "new1@example.com")

      html = add_row(lv)
      [_, row_id2] = row_ids(html)
      fill_row(lv, row_id2, "new2@example.com")

      html = add_row(lv)
      [_, _, row_id3] = row_ids(html)
      fill_row(lv, row_id3, "new3@example.com")

      html = add_row(lv)
      [_, _, _, row_id4] = row_ids(html)
      fill_row(lv, row_id4, "new4@example.com")

      assert submit_form(lv) =~ "Your account is limited to 3 team members"
      refute Repo.reload!(team).setup_complete
      assert_no_emails_delivered()
    end
  end

  defp type_into_input(lv, id, text) do
    lv
    |> element("form#update-team-form")
    |> render_change(%{id => text})
  end

  defp row_el(), do: ~s|#member-rows > div|

  defp row_ids(html) do
    html
    |> find(~s|button[phx-click="remove-row"]|)
    |> Enum.map(&text_of_attr(&1, "phx-value-row-id"))
  end

  defp add_row(lv) do
    lv
    |> element(~s|button[phx-click="add-row"]|)
    |> render_click()
  end

  defp remove_row(lv, row_id) do
    lv
    |> element(~s|button[phx-click="remove-row"][phx-value-row-id="#{row_id}"]|)
    |> render_click()
  end

  defp fill_row(lv, row_id, email) do
    lv
    |> element("#member-rows-form")
    |> render_change(%{"rows" => %{row_id => %{"email" => email}}})
  end

  defp select_role(lv, row_id, role) do
    lv
    |> element(~s|#role-picker-#{row_id} a[phx-value-role="#{role}"]|)
    |> render_click()
  end

  defp submit_form(lv) do
    lv
    |> element("#member-rows-form")
    |> render_submit()
  end
end
