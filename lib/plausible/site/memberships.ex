defmodule Plausible.Site.Memberships do
  @moduledoc """
  API for site memberships and invitations
  """

  import Ecto.Query, only: [from: 2]

  alias Plausible.Auth
  alias Plausible.Repo
  alias Plausible.Site.Memberships

  defdelegate accept_invitation(invitation_id, user), to: Memberships.AcceptInvitation
  defdelegate reject_invitation(invitation_id, user), to: Memberships.RejectInvitation
  defdelegate remove_invitation(invitation_id, site), to: Memberships.RemoveInvitation

  defdelegate create_invitation(site, inviter, invitee_email, role),
    to: Memberships.CreateInvitation

  defdelegate bulk_create_invitation(sites, inviter, invitee_email, role, opts),
    to: Memberships.CreateInvitation

  defdelegate bulk_transfer_ownership_direct(current_user, sites, new_owner),
    to: Memberships.AcceptInvitation

  @spec any?(Auth.User.t()) :: boolean()
  def any?(user) do
    user
    |> Ecto.assoc(:site_memberships)
    |> Repo.exists?()
  end

  @spec pending?(String.t()) :: boolean()
  def pending?(email) do
    Repo.exists?(
      from(i in Plausible.Auth.Invitation,
        where: i.email == ^email
      )
    )
  end

  @spec any_or_pending?(Plausible.Auth.User.t()) :: boolean()
  def any_or_pending?(user) do
    invitation_query =
      from(i in Plausible.Auth.Invitation,
        where: i.email == ^user.email,
        select: 1
      )

    from(sm in Plausible.Site.Membership,
      where: sm.user_id == ^user.id or exists(invitation_query),
      select: 1
    )
    |> Repo.exists?()
  end
end
