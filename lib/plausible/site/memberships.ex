defmodule Plausible.Site.Memberships do
  @moduledoc """
  API for site memberships and invitations
  """

  alias Plausible.Site.Memberships

  defdelegate accept_invitation(invitation_id, user, team \\ nil),
    to: Memberships.AcceptInvitation

  defdelegate reject_invitation(invitation_id, user), to: Memberships.RejectInvitation
  defdelegate remove_invitation(invitation_id, site), to: Memberships.RemoveInvitation

  defdelegate create_invitation(site, inviter, invitee_email, role),
    to: Memberships.CreateInvitation

  defdelegate bulk_create_invitation(sites, inviter, invitee_email, role, opts),
    to: Memberships.CreateInvitation

  defdelegate bulk_transfer_ownership_direct(sites, new_owner, team \\ nil),
    to: Memberships.AcceptInvitation
end
