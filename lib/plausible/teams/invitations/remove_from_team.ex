defmodule Plausible.Teams.Invitations.RemoveFromTeam do
  @moduledoc """
  Service for removing a team invitation.
  """

  alias Plausible.Repo
  alias Plausible.Teams.Invitations
  alias Plausible.Teams.Memberships

  def remove(nil, _invitation_id, _current_user) do
    {:error, :permission_denied}
  end

  def remove(team, invitation_id, current_user) do
    with {:ok, team_invitation} <- Invitations.get_team_invitation(team, invitation_id),
         {:ok, current_user_role} <- Memberships.team_role(team, current_user),
         :ok <- check_can_remove_invitation(current_user_role) do
      Repo.delete!(team_invitation)

      {:ok, team_invitation}
    end
  end

  defp check_can_remove_invitation(role) do
    if role in [:owner, :admin] do
      :ok
    else
      {:error, :permission_denied}
    end
  end
end
