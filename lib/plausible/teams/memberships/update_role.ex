defmodule Plausible.Teams.Memberships.UpdateRole do
  @moduledoc """
  Service for updating role of a team member.
  """

  alias Plausible.Repo
  alias Plausible.Teams
  alias Plausible.Teams.Memberships

  def update(team, user_id, new_role_str, current_user) do
    new_role = String.to_existing_atom(new_role_str)

    with :ok <- check_valid_role(new_role),
         {:ok, team_membership} <- Memberships.get_team_membership(team, user_id),
         {:ok, current_user_role} <- Memberships.team_role(team, current_user),
         granting_to_self? = team_membership.user_id == user_id,
         :ok <- check_can_grant_role(current_user_role, new_role, granting_to_self?),
         :ok <- check_owner_can_get_demoted(team, team_membership.role, new_role) do
      team_membership =
        team_membership
        |> Ecto.Changeset.change(role: new_role)
        |> Repo.update!()
        |> Repo.preload(:user)

      {:ok, team_membership}
    end
  end

  defp check_valid_role(role) do
    if role in (Teams.Membership.roles() -- [:guest]) do
      :ok
    else
      {:error, :invalid_role}
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

  defp check_can_grant_role(user_role, role, true) do
    if can_grant_role_to_self?(user_role, role) do
      :ok
    else
      {:error, :permission_denied}
    end
  end

  defp check_can_grant_role(user_role, role, false) do
    if can_grant_role_to_other?(user_role, role) do
      :ok
    else
      {:error, :permission_denied}
    end
  end

  defp can_grant_role_to_self?(:owner, :admin), do: true
  defp can_grant_role_to_self?(:owner, :editor), do: true
  defp can_grant_role_to_self?(:owner, :viewer), do: true
  defp can_grant_role_to_self?(:admin, :editor), do: true
  defp can_grant_role_to_self?(:admin, :viewer), do: true
  defp can_grant_role_to_self?(_, _), do: false

  defp can_grant_role_to_other?(:owner, :owner), do: true
  defp can_grant_role_to_other?(:owner, :editor), do: true
  defp can_grant_role_to_other?(:owner, :admin), do: true
  defp can_grant_role_to_other?(:owner, :viewer), do: true
  defp can_grant_role_to_other?(:admin, :admin), do: true
  defp can_grant_role_to_other?(:admin, :editor), do: true
  defp can_grant_role_to_other?(:admin, :viewer), do: true
  defp can_grant_role_to_other?(_, _), do: false
end
