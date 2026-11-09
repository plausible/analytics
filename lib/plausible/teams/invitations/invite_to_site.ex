defmodule Plausible.Teams.Invitations.InviteToSite do
  @moduledoc """
  Service for inviting guest members to sites.
  """

  alias Plausible.Auth.User
  alias Plausible.Repo
  alias Plausible.Site
  alias Plausible.Teams
  use Plausible

  @type invite_error() ::
          Ecto.Changeset.t()
          | :already_a_member
          | {:over_limit, non_neg_integer()}
          | :permission_denied

  @doc """
  Invites a new guest member to the given site. Returns a
  `%Teams.GuestInvitation{}` struct and sends the invitee
  an email to accept this invitation.

  The inviter must have enough permissions to invite the new team member,
  otherwise this function returns `{:error, :permission_denied}`.
  """
  @spec invite(Site.t(), User.t(), String.t(), atom()) ::
          {:ok, Teams.GuestInvitation.t()} | {:error, invite_error()}
  def invite(site, inviter, invitee_email, role) do
    Repo.transaction(fn ->
      do_invite(site, inviter, invitee_email, role)
    end)
  end

  defp do_invite(site, inviter, invitee_email, role) do
    with site <- Repo.preload(site, [:owners, :team]),
         :ok <- Teams.TeamRolePermissions.ensure_can_manage_team(site.team, inviter),
         :ok <- Teams.Invitations.check_team_member_limit(site.team, role, invitee_email),
         invitee = Plausible.Auth.find_user_by(email: invitee_email),
         :ok <- Teams.Invitations.ensure_new_membership(site, invitee, role),
         {:ok, guest_invitation} <-
           Teams.Invitations.invite(site, invitee_email, role, inviter) do
      send_invitation_email(guest_invitation, invitee)

      guest_invitation
    else
      {:error, cause} -> Repo.rollback(cause)
    end
  end

  defp send_invitation_email(%Teams.GuestInvitation{} = guest_invitation, invitee) do
    guest_invitation
    |> Repo.preload([:site, team_invitation: :inviter])
    |> Teams.Invitations.send_invitation_email(invitee)
  end
end
