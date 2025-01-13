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
  end

  defp type_into_input(lv, id, text) do
    lv
    |> element("form")
    |> render_change(%{id => text})
  end
end
