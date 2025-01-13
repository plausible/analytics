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

  describe "/team/setup" do
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

    test "existing member is suggested from combobox dropdown"

    test "team member is added from input", %{conn: conn, user: user} do
      new_member_email = build(:user).email

      {:ok, lv, _html} = live(conn, @url)

      type_into_combo(lv, "team-member-candidates", new_member_email)

      lv
      |> element(~s/li#dropdown-team-member-candidates-option-0 a/)
      |> render_click()

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
end
