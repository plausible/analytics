defmodule Plausible.Site.Memberships do
  @moduledoc """
  API for site memberships and invitations
  """

  import Ecto.Query, only: [from: 2]

  alias Plausible.Repo
  alias Plausible.Site.Memberships

  defdelegate accept_invitation(invitation_id, user), to: Memberships.AcceptInvitation
  defdelegate reject_invitation(invitation_id, user), to: Memberships.RejectInvitation
  defdelegate remove_invitation(invitation_id, site), to: Memberships.RemoveInvitation

  @spec any?(String.t()) :: boolean()
  def any?(user_id) do
    Repo.exists?(
      from(m in Plausible.Site.Membership,
        where: m.user_id == ^user_id
      )
    )
  end

  @spec has_any_invitations?(String.t()) :: boolean()
  def has_any_invitations?(email) do
    Repo.exists?(
      from(i in Plausible.Auth.Invitation,
        where: i.email == ^email
      )
    )
  end
end
