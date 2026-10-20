defmodule Plausible.Teams.Invitations.UpdateRole do
  @moduledoc """
  Service for changing the role of a pending team invitation.

  This edits an invitation that already exists, so no e-mail is sent and
  the invitation keeps its original expiry.

  Guest invitations can't be promoted to team invitations this way because
  otherwise the link in the invitation e-mail would stop working.
  """

  alias Plausible.{Repo, Teams}

  @spec update(Teams.Team.t(), String.t(), atom(), Plausible.Auth.User.t()) ::
          {:ok, Teams.Invitation.t()}
          | {:error,
             :permission_denied
             | :invitation_not_found
             | :guest_invitation
             | Ecto.Changeset.t()}
  def update(%Teams.Team{} = team, invitation_id, new_role, current_user) do
    with {:ok, invitation} <- Teams.Invitations.get_team_invitation(team, invitation_id),
         :ok <- ensure_team_invitation(invitation),
         :ok <-
           Teams.TeamRolePermissions.ensure_can_grant_for_invitation(
             team,
             current_user,
             invitation,
             new_role
           ) do
      invitation
      |> Ecto.Changeset.change(role: new_role)
      |> Repo.update()
    end
  end

  defp ensure_team_invitation(%Teams.Invitation{role: :guest}), do: {:error, :guest_invitation}
  defp ensure_team_invitation(%Teams.Invitation{}), do: :ok
end
