defmodule Plausible.Stats.ConsolidatedViewSyncTest do
  use Plausible.DataCase, async: true

  on_ee do
    import Plausible.Teams.Test
    import Plausible.ConsolidatedView, only: [ok_to_display?: 2, enable: 1]

    describe "ok_to_display?/2" do
      setup [:create_user, :create_team]

      test "no user", %{team: team}  do
        refute ok_to_display?(team, nil)
      end

      test "no team", %{user: user}  do
        refute ok_to_display?(nil, user)
      end

      test "success", %{team: team, user: user} do
        new_site(owner: user)
        new_site(owner: user)

        team = Plausible.Teams.complete_setup(team)

        {:ok, _} = enable(team)

        patch_env(:super_admin_user_ids, [user.id])

        assert ok_to_display?(team, user)
      end

      test "not super-admin (temporary - feature-flag-like)", %{team: team, user: user} do
        new_site(owner: user)
        new_site(owner: user)

        team = Plausible.Teams.complete_setup(team)

        {:ok, _} = enable(team)

        refute ok_to_display?(team, user)
      end

      test "not enabled", %{team: team, user: user} do
        new_site(owner: user)
        new_site(owner: user)

        team = Plausible.Teams.complete_setup(team)

        patch_env(:super_admin_user_ids, [user.id])

        refute ok_to_display?(team, user)
      end


    end
  end

end
