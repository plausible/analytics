defmodule Plausible.Teams.Memberships.Remove do
  @moduledoc """
  Service for removing a team member.
  """

  alias Plausible.Repo
  alias Plausible.Teams.Memberships

  def remove(nil, _, _), do: {:error, :permission_denied}

  def remove(team, user_id, current_user, opts \\ []) do
    with {:ok, team_membership} <- Memberships.get_team_membership(team, user_id),
         {:ok, current_user_role} <- Memberships.team_role(team, current_user),
         :ok <- check_can_remove_membership(current_user_role, team_membership.role),
         :ok <- check_owner_can_get_removed(team, team_membership.role) do
      team_membership = Repo.preload(team_membership, [:team, :user])
      Repo.delete!(team_membership)

      if Keyword.get(opts, :send_email?, true) do
        send_team_member_removed_email(team_membership)
      end

      {:ok, team_membership}
    end
  end

  defp check_can_remove_membership(:owner, _), do: :ok
  defp check_can_remove_membership(:admin, role) when role != :owner, do: :ok
  defp check_can_remove_membership(_, _), do: {:error, :permission_denied}

  defp check_owner_can_get_removed(team, :owner) do
    if Memberships.owners_count(team) > 1 do
      :ok
    else
      {:error, :only_one_owner}
    end
  end

  defp check_owner_can_get_removed(_team, _role), do: :ok

  def send_team_member_removed_email(team_membership) do
    team_membership
    |> PlausibleWeb.Email.team_member_removed()
    |> Plausible.Mailer.send()
  end
end
