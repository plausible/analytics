defmodule Plausible.Site.Memberships.Invitations do
  @moduledoc false

  import Ecto.Query, only: [from: 2, where: 3]

  alias Plausible.Auth
  alias Plausible.Repo

  @spec list_for_email(String.t()) :: [Auth.Invitation.t()]
  def list_for_email(email, opts \\ []) do
    domain_filter = Keyword.get(opts, :filter_by_domain)

    Repo.all(
      from(i in Auth.Invitation,
        inner_join: s in assoc(i, :site),
        where: i.email == ^email,
        preload: [site: s]
      )
      |> maybe_filter_by_domain(domain_filter)
    )
  end

  defp maybe_filter_by_domain(query, domain)
       when byte_size(domain) >= 3 and byte_size(domain) <= 64 do
    where(query, [_, s], ilike(s.domain, ^"%#{domain}%"))
  end

  defp maybe_filter_by_domain(query, _) do
    query
  end

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

  @spec delete_invitation(Auth.Invitation.t()) :: :ok
  def delete_invitation(invitation) do
    Repo.delete_all(from(i in Auth.Invitation, where: i.id == ^invitation.id))

    :ok
  end
end
