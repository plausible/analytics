defmodule PlausibleWeb.Live.SitesTest do
  use PlausibleWeb.ConnCase, async: true

  alias Plausible.Teams
  use Plausible.Teams.Test

  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  alias Plausible.Repo

  @url "/team/setup"

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
      assert {:ok, _, _} = live(conn, @url <> "?dev=1")
    end
  end

  describe "/team/setup - functional details" do
    setup [:create_user, :log_in, :create_team]

    test "renders form", %{conn: conn} do
      {:ok, _, html} = live(conn, @url)
      assert element_exists?(html, ~s|input#team_name[name="team[name]"]|)
      assert element_exists?(html, ~s|input[name="team-member-candidate"]|)
      assert element_exists?(html, ~s|button[phx-click="setup-team"]|)
    end

    test "changing team name, updates team name in db", %{conn: conn, team: team} do
      {:ok, lv, _html} = live(conn, @url)
      type_into_input(lv, "team[name]", "New Team Name")
      assert Repo.reload!(team).name == "New Team Name"
    end

    test "existing guest is suggested from combobox dropdown", %{conn: conn, user: user} do
      site = new_site(owner: user)
      guest = add_guest(site, role: :viewer)

      {:ok, lv, _html} = live(conn, @url)

      type_into_combo(lv, "team-member-candidates", guest.email)
      select_combo_option(lv, 1)

      [member1_row, member2_row] =
        lv
        |> render()
        |> find(".member")

      assert text(member1_row) =~ user.name
      assert text(member1_row) =~ "You"
      assert text(member1_row) =~ user.email

      assert text(member2_row) =~ guest.name
      assert text(member2_row) =~ guest.email

      assert member1_row |> Floki.find(".role") |> text() =~ "Owner"
      assert member2_row |> Floki.find(".role") |> text() =~ "Viewer"
    end

    test "team member is added from input", %{conn: conn, user: user} do
      new_member_email = build(:user).email

      {:ok, lv, _html} = live(conn, @url)

      type_into_combo(lv, "team-member-candidates", new_member_email)
      select_combo_option(lv, 0)

      [member1_row, member2_row] =
        lv
        |> render()
        |> find(".member")

      assert text(member1_row) =~ user.name
      assert text(member1_row) =~ "You"
      assert text(member1_row) =~ user.email

      assert text(member2_row) =~ "Invited User"
      assert text(member2_row) =~ new_member_email

      assert member1_row |> Floki.find(".role") |> text() =~ "Owner"
      assert member2_row |> Floki.find(".role") |> text() =~ "Viewer"
    end

    test "arbitrary invalid e-mail attempt", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @url)
      type_into_combo(lv, "team-member-candidates", "invalid")

      refute lv |> render |> text() =~ "Sorry"

      select_combo_option(lv, 0)

      assert lv |> render() |> text() =~
               "Sorry, e-mail 'invalid' is invalid. Please type the address again."
    end

    test "owner's own e-mail attempt", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, @url)
      type_into_combo(lv, "team-member-candidates", user.email)

      refute lv |> render |> text() =~ "Sorry"

      select_combo_option(lv, 0)

      assert lv |> render() |> text() =~
               "Sorry, e-mail '#{user.email}' is invalid. Please type the address again."
    end

    test "owner's role dropdown consists of inactive options", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @url)

      assert html
             |> find(".member")
             |> Enum.take(1)
             |> find(".dropdown-items > *:not([^role=separator])")
             |> Enum.all?(fn el ->
               text_of_attr(el, "data-ui-state") == "disabled"
             end)
    end

    test "candidate's role dropdown allows changing role", %{conn: conn} do
      new_member_email = build(:user).email
      {:ok, lv, _html} = live(conn, @url)

      type_into_combo(lv, "team-member-candidates", new_member_email)
      select_combo_option(lv, 0)

      lv
      |> element(~s|.member a[phx-click="update-role"][phx-value-role="admin"]|)
      |> render_click()

      member2_row = lv |> render() |> find(".member:nth-of-type(2) .role") |> text()
      assert member2_row =~ "Admin"

      lv
      |> element(~s|.member a[phx-click="update-role"][phx-value-role="viewer"]|)
      |> render_click()

      member2_row = lv |> render() |> find(".member:nth-of-type(2) .role") |> text()
      assert member2_row =~ "Viewer"
    end

    test "member candidate suggestion disappears when selected", %{conn: conn, user: user} do
      site = new_site(owner: user)
      guest = add_guest(site, role: :viewer)

      {:ok, lv, _html} = live(conn, @url)

      type_into_combo(lv, "team-member-candidates", guest.email)

      assert lv
             |> render()
             |> find("#dropdown-team-member-candidates")
             |> text() =~ guest.email

      select_combo_option(lv, 1)

      refute lv
             |> render()
             |> find("#dropdown-team-member-candidates")
             |> text() =~ guest.email
    end

    test "member candidate can be removed", %{conn: conn, user: user} do
      site = new_site(owner: user)

      guest = add_guest(site, role: :viewer)

      {:ok, lv, _html} = live(conn, @url)

      type_into_combo(lv, "team-member-candidates", guest.email)
      select_combo_option(lv, 1)

      assert lv
             |> render()
             |> find(".member:nth-of-type(2)")
             |> text() =~ guest.email

      lv
      |> element(~s|.member a[phx-click="remove-member"][phx-value-email="#{guest.email}"]|)
      |> render_click()

      refute lv
             |> render()
             |> find(".member")
             |> text() =~ guest.email
    end
  end

  defp type_into_input(lv, id, text) do
    lv
    |> element("form")
    |> render_change(%{id => text})
  end

  defp type_into_combo(lv, id, text) do
    lv
    |> element("input##{id}")
    |> render_change(%{
      "_target" => ["display-#{id}"],
      "display-#{id}" => "#{text}"
    })
  end

  defp select_combo_option(lv, index) do
    lv
    |> element(~s/li#dropdown-team-member-candidates-option-#{index} a/)
    |> render_click()
  end
end
