defmodule Plausible.Teams.Invitations.Reject do
  @moduledoc """
  Service for rejecting invitations.
  """

  alias Plausible.Auth
  alias Plausible.Teams

  @spec reject_invitation(String.t(), Auth.User.t()) ::
          {:ok, Teams.GuestInvitation.t() | Teams.SiteTransfer.t()}
          | {:error, :invitation_not_found}
  def reject_invitation(invitation_or_transfer_id, user) do
    with {:ok, invitation_or_transfer} <-
           Teams.Invitations.find_for_user(invitation_or_transfer_id, user) do
      do_reject(invitation_or_transfer)
      {:ok, invitation_or_transfer}
    end
  end

  defp do_reject(%Teams.Invitation{} = team_invitation) do
    Teams.Invitations.remove_team_invitation(team_invitation)

    notify_team_invitation_rejected(team_invitation)
  end

  defp do_reject(%Teams.GuestInvitation{} = guest_invitation) do
    Teams.Invitations.remove_guest_invitation(guest_invitation)

    notify_guest_invitation_rejected(guest_invitation)
  end

  defp do_reject(%Teams.SiteTransfer{} = site_transfer) do
    Teams.Invitations.remove_site_transfer(site_transfer)

    notify_site_transfer_rejected(site_transfer)
  end

  defp notify_site_transfer_rejected(site_transfer) do
    PlausibleWeb.Email.ownership_transfer_rejected(site_transfer)
    |> Plausible.Mailer.send()
  end

  defp notify_guest_invitation_rejected(guest_invitation) do
    PlausibleWeb.Email.guest_invitation_rejected(guest_invitation)
    |> Plausible.Mailer.send()
  end

  defp notify_team_invitation_rejected(team_invitation) do
    PlausibleWeb.Email.team_invitation_rejected(team_invitation)
    |> Plausible.Mailer.send()
  end
end
