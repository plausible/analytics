defmodule Plausible.Site.Memberships do
  @moduledoc """
  API for site memberships and invitations
  """

  alias Plausible.Site.Memberships

  defdelegate accept_invitation(invitation_id, user), to: Memberships.AcceptInvitation
  defdelegate reject_invitation(invitation_id, user), to: Memberships.RejectInvitation
  defdelegate remove_invitation(invitation_id, site), to: Memberships.RemoveInvitation
end
