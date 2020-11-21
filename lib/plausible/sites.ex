defmodule Plausible.Sites do
  use Plausible.Repo
  alias Plausible.Site.CustomDomain

  def get_for_user!(user_id, domain) do
    Repo.one!(
      from s in Plausible.Site,
        join: sm in Plausible.Site.Membership,
        on: sm.site_id == s.id,
        where: sm.user_id == ^user_id,
        where: s.domain == ^domain,
        select: s
    )
  end

  def members(site_id) when is_integer(site_id) do
    from(u in Plausible.Auth.User,
      join: sm in Plausible.Site.Membership,
      on: sm.user_id == u.id,
      where: sm.site_id == ^site_id,
      select: [u, sm.role]
    )
    |> Repo.all()
    |> Enum.map(fn [user, role] -> Map.put(user, :role, role) end)
  end

  def has_goals?(site) do
    Repo.exists?(
      from g in Plausible.Goal,
        where: g.domain == ^site.domain
    )
  end

  def is_owner?(user_id, site) do
    Repo.exists?(
      from s in Plausible.Site,
        where: s.owner_id == ^user_id and s.id == ^site.id
    )
  end

  def add_custom_domain(site, custom_domain) do
    CustomDomain.changeset(%CustomDomain{}, %{
      site_id: site.id,
      domain: custom_domain
    })
    |> Repo.insert()
  end

  def is_admin?(user_id, site) do
    Repo.exists?(
      from sm in Plausible.Site.Membership,
        where: sm.user_id == ^user_id and sm.site_id == ^site.id
    )
  end
end
