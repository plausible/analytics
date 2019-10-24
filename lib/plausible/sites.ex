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

  def has_pageviews?(site) do
    Repo.exists?(
      from e in Plausible.Event,
      where: e.hostname == ^site.domain
    )
  end

  def is_owner?(user_id, site) do
    Repo.exists?(
      from sm in Plausible.Site.Membership,
      where: sm.user_id == ^user_id and sm.site_id == ^site.id
    )
  end
end
