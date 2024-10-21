defmodule Plausible.Teams.Test do
  alias Plausible.Repo

  use ExUnit.CaseTemplate

  defmacro __using__(_) do
    quote do
      import Plausible.Teams.Test
    end
  end

  def assert_team_exists(user, team_id \\ nil) do
    assert %{team_memberships: memberships} = Repo.preload(user, team_memberships: :team)

    tm =
      case memberships do
        [tm] -> tm
        _ -> raise "Team doesn't exist for user #{user.id}"
      end

    assert tm.role == :owner
    assert tm.team.id

    if team_id do
      assert tm.team.id == team_id
    end

    tm.team
  end

  def assert_team_attached(site, team_id \\ nil) do
    assert site = %{team: team} = site |> Repo.reload!() |> Repo.preload([:team, :owner])

    assert membership =
             Repo.get_by(Plausible.Teams.Membership,
               team_id: team.id,
               user_id: site.owner.id,
               role: :owner
             )

    assert membership.team_id == team.id

    if team_id do
      assert team.id == team_id
    end

    team
  end

  def assert_guest_invitation(team, site, email, role) do
    assert team_invitation =
             Repo.get_by(Plausible.Teams.Invitation,
               email: email,
               team_id: team.id,
               role: :guest
             )

    assert Repo.get_by(Plausible.Teams.GuestInvitation,
             team_invitation_id: team_invitation.id,
             site_id: site.id,
             role: role
           )
  end
end
