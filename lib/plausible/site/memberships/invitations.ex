defmodule Plausible.Site.Memberships.Invitations do
  @moduledoc false

  alias Plausible.Auth
  alias Plausible.Repo

  @spec find_for_user(String.t(), Auth.User.t()) ::
          {:ok, Auth.Invitation.t()} | {:error, :invitation_not_found}
  def find_for_user(invitation_id, user) do
    invitation =
      Auth.Invitation
      |> Repo.get_by(invitation_id: invitation_id, email: user.email)
      |> Repo.preload([:site, :inviter])

    if invitation do
      {:ok, invitation}
    else
      {:error, :invitation_not_found}
    end
  end

  @spec find_for_site(String.t(), Plausible.Site.t()) ::
          {:ok, Auth.Invitation.t()} | {:error, :invitation_not_found}
  def find_for_site(invitation_id, site) do
    invitation =
      Auth.Invitation
      |> Repo.get_by(invitation_id: invitation_id, site_id: site.id)
      |> Repo.preload([:site, :inviter])

    if invitation do
      {:ok, invitation}
    else
      {:error, :invitation_not_found}
    end
  end
end
