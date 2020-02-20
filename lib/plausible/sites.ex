defmodule Plausible.Sites do
  use Plausible.Repo
  alias Plausible.Site.CustomDomain

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
      where: e.domain == ^site.domain
    )
  end

  def has_goals?(site) do
    Repo.exists?(
      from g in Plausible.Goal,
      where: g.domain == ^site.domain
    )
  end

  def is_owner?(user_id, site) do
    Repo.exists?(
      from sm in Plausible.Site.Membership,
      where: sm.user_id == ^user_id and sm.site_id == ^site.id
    )
  end

  def add_custom_domain(site, custom_domain) do
    CustomDomain.changeset(%CustomDomain{}, %{
      site_id: site.id,
      domain: custom_domain
    }) |> Repo.insert
  end
end
