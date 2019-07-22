defmodule Plausible.Sites do
  use Plausible.Repo

  def get_for_user!(user_id, domain) do
    Repo.one!(
      from s in Plausible.Site,
      join: sm in Plausible.Site.Membership, on: sm.site_id == s.id,
      where: sm.user_id == ^user_id,
      where: s.domain == ^domain,
      select: s
    )
  end

  def can_access?(user_id, site) do
    Repo.exists?(
      from sm in Plausible.Site.Membership,
      where: sm.user_id == ^user_id and sm.site_id == ^site.id
    )
  end

  def google_auth_for(site) do
    membership = Repo.get_by(Plausible.Site.Membership, site_id: site.id)
    owner_id = membership.user_id
    Repo.get_by(Plausible.Site.GoogleAuth, user_id: owner_id)
  end
end
