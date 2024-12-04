defmodule Plausible.Teams.Adapter.Read.Invitations do
  @moduledoc """
  Transition adapter for new schema reads
  """
  use Plausible
  use Plausible.Teams.Adapter

  alias Plausible.Repo

  def ensure_new_membership(inviter, site, invitee, role) do
    switch(
      inviter,
      team_fn: fn _ ->
        Plausible.Teams.Invitations.ensure_new_membership(
          site,
          invitee,
          role
        )
      end,
      user_fn: fn _ ->
        Plausible.Site.Memberships.CreateInvitation.ensure_new_membership(
          site,
          invitee,
          role
        )
      end
    )
  end

  def send_invitation_email(inviter, invitation, invitee) do
    switch(
      inviter,
      team_fn: fn _ ->
        if invitation.role == :owner do
          Teams.SiteTransfer
          |> Repo.get_by!(transfer_id: invitation.invitation_id, initiator_id: inviter.id)
          |> Repo.preload([:site, :initiator])
          |> Plausible.Teams.Invitations.send_invitation_email(invitee)
        else
          Teams.GuestInvitation
          |> Repo.get_by!(invitation_id: invitation.invitation_id)
          |> Repo.preload([:site, team_invitation: :inviter])
          |> Plausible.Teams.Invitations.send_invitation_email(invitee)
        end
      end,
      user_fn: fn _ ->
        Plausible.Site.Memberships.CreateInvitation.send_invitation_email(
          invitation,
          invitee
        )
      end
    )
  end
end
