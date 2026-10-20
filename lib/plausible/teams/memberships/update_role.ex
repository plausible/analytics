defmodule Plausible.Teams.Memberships.UpdateRole do
  @moduledoc """
  Service for updating role of a team member.
  """

  use Plausible

  alias Plausible.Repo
  alias Plausible.Teams
  alias Plausible.Teams.Memberships

  def update(%Teams.Team{} = team, user_id, new_role, current_user) do
    with {:ok, team_membership} <- Memberships.get_team_membership(team, user_id),
         :ok <-
           Teams.TeamRolePermissions.ensure_can_grant_for_member(
             team,
             current_user,
             team_membership,
             new_role
           ),
         :ok <- check_owner_can_get_demoted(team, team_membership.role, new_role),
         team_membership = Repo.preload(team_membership, :user),
         :ok <- check_can_promote_to_owner(team, team_membership.user, new_role) do
      if team_membership.role == :guest do
        team_membership.user.email
        |> PlausibleWeb.Email.guest_to_team_member_promotion(
          team,
          current_user
        )
        |> Plausible.Mailer.send()
      end

      team_membership =
        team_membership
        |> Ecto.Changeset.change(role: new_role)
        |> Repo.update!()

      :ok = maybe_prune_guest_memberships(team_membership)

      {:ok, team_membership}
    end
  end

  on_ee do
    defp check_can_promote_to_owner(team, user, :owner) do
      if team.policy.force_sso == :all_but_owners and not Plausible.Auth.TOTP.enabled?(user) do
        {:error, :disabled_2fa}
      else
        :ok
      end
    end

    defp check_can_promote_to_owner(_team, _user, _new_role), do: :ok
  else
    defp check_can_promote_to_owner(_team, _user, _new_role) do
      # The `else` branch is not reachable.
      # This a workaround for Elixir 1.18+ compiler
      # being too smart.
      if :erlang.phash2(1, 1) == 0 do
        :ok
      else
        {:error, :disabled_2fa}
      end
    end
  end

  defp check_owner_can_get_demoted(team, :owner, new_role) when new_role != :owner do
    if Memberships.owners_count(team) > 1 do
      :ok
    else
      {:error, :only_one_owner}
    end
  end

  defp check_owner_can_get_demoted(_team, _current_role, _new_role), do: :ok

  defp maybe_prune_guest_memberships(%Teams.Membership{role: :guest}),
    do: :ok

  defp maybe_prune_guest_memberships(%Teams.Membership{} = team_membership) do
    team_membership
    |> Ecto.assoc(:guest_memberships)
    |> Repo.delete_all()

    :ok
  end
end
