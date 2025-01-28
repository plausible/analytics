defmodule PlausibleWeb.Live.TeamSetupSyncTest do
  use PlausibleWeb.ConnCase, async: false
  use Bamboo.Test, shared: true

  use Plausible.Teams.Test

  import Phoenix.LiveViewTest

  alias Plausible.Repo

  @url "/team/setup"

  describe "/team/setup - full integration" do
    setup [:create_user, :log_in, :create_team]

    @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "

    test "setting up a team successfully creates invitations", %{
      conn: conn,
      user: user,
      team: team
    } do
      site = new_site(owner: user)
      guest = add_guest(site, role: :viewer)

      assert team |> Ecto.assoc(:team_invitations) |> Repo.aggregate(:count) == 0
      refute Repo.reload!(team).setup_complete

      extra_guests = build_list(2, :user)

      {:ok, lv, _html} = live(conn, @url)

      type_into_input(lv, "team[name]", "New Team Name")
      type_into_combo(lv, "team-member-candidates", guest.email)
      select_combo_option(lv, 1)

      for g <- extra_guests do
        type_into_combo(lv, "team-member-candidates", g.email)
        select_combo_option(lv, 0)
      end

      lv |> element(~s|button[phx-click="setup-team"]|) |> render_click()

      assert team |> Ecto.assoc(:team_invitations) |> Repo.aggregate(:count) == 3

      for %{email: email} <- Enum.reverse([guest | extra_guests]) do
        assert_email_delivered_with(
          to: [nil: email],
          subject: @subject_prefix <> "You've been invited to \"New Team Name\" team"
        )
      end

      team = Repo.reload!(team)
      assert team.setup_complete
      assert team.name == "New Team Name"
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
