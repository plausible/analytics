defmodule Plausible.Site.Memberships.Invitations do
  @moduledoc false

  use Plausible

  alias Plausible.Auth
  alias Plausible.Repo
  alias Plausible.Billing.Feature
  alias Plausible.Teams

  @type missing_features_error() :: {:missing_features, [Feature.t()]}

  @spec find_for_user(String.t(), Auth.User.t()) ::
          {:ok, Auth.Invitation.t()} | {:error, :invitation_not_found}
  def find_for_user(guest_invitation_id, user) do
    invitation =
      Teams.GuestInvitation
      |> Repo.get_by(invitation_id: guest_invitation_id, email: user.email)
      |> Repo.preload([:site, team_invitation: :inviter])

    if invitation do
      {:ok, invitation}
    else
      {:error, :invitation_not_found}
    end
  end

  @spec find_for_site(String.t(), Plausible.Site.t()) ::
          {:ok, Auth.Invitation.t()} | {:error, :invitation_not_found}
  def find_for_site(guest_invitation_id, site) do
    invitation =
      Teams.GuestInvitation
      |> Repo.get_by(invitation_id: guest_invitation_id, site_id: site.id)
      |> Repo.preload([:site, team_invitation: :inviter])

    if invitation do
      {:ok, invitation}
    else
      {:error, :invitation_not_found}
    end
  end

  @spec delete_invitation(Teams.GuestInvitation.t() | Plausible.Teams.SiteTransfer.t()) :: :ok
  def delete_invitation(%Teams.GuestInvitation{} = invitation) do
    Plausible.Teams.Invitations.remove_invitation_sync(invitation)
  end

  def delete_invitation(_) do
    raise "implement me"
  end
end
