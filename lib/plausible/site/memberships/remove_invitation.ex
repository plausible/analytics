defmodule Plausible.Site.Memberships.RemoveInvitation do
  @moduledoc """
  Service for removing invitations.
  """

  alias Plausible.Teams

  @spec remove_invitation(String.t(), Plausible.Site.t()) ::
          {:ok, Teams.GuestInvitation.t() | Teams.SiteTransfer.t()}
          | {:error, :invitation_not_found}
  def remove_invitation(invitation_or_transfer_id, site) do
    with {:ok, invitation_or_transfer} <-
           Teams.Invitations.find_for_site(invitation_or_transfer_id, site) do
      do_delete(invitation_or_transfer)

      {:ok, invitation_or_transfer}
    end
  end

  defp do_delete(%Teams.GuestInvitation{} = guest_invitation) do
    Teams.Invitations.remove_guest_invitation(guest_invitation)
  end

  defp do_delete(%Teams.SiteTransfer{} = site_transfer) do
    Teams.Invitations.remove_site_transfer(site_transfer)
  end
end
