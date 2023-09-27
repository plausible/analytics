defmodule Plausible.Site.Memberships do
  @moduledoc """
  API for site memberships and invitations
  """

  alias Plausible.Site.Memberships

  defdelegate accept_invitation(invitation_id, user), to: Memberships.AcceptInvitation
end
