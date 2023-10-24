defmodule Plausible.Sites do
  alias Plausible.{Repo, Site, Site.SharedLink, Billing.Quota}
  import Ecto.Query

  def get_by_domain(domain) do
    Repo.get_by(Site, domain: domain)
  end

  def get_by_domain!(domain) do
    Repo.get_by!(Site, domain: domain)
  end

  def create(user, params) do
    site_changeset = Site.changeset(%Site{}, params)

    Ecto.Multi.new()
    |> Ecto.Multi.run(:limit, fn _, _ ->
      limit = Quota.site_limit(user)
      usage = Quota.site_usage(user)

      if Quota.within_limit?(usage, limit), do: {:ok, usage}, else: {:error, limit}
    end)
    |> Ecto.Multi.insert(:site, site_changeset)
    |> Ecto.Multi.insert(:site_membership, fn %{site: site} ->
      Site.Membership.new(site, user)
    end)
    |> maybe_start_trial(user)
    |> Repo.transaction()
  end

  defp maybe_start_trial(multi, user) do
    case user.trial_expiry_date do
      nil ->
        changeset = Plausible.Auth.User.start_trial(user)
        Ecto.Multi.update(multi, :user, changeset)

      _ ->
        multi
    end
  end

  @spec stats_start_date(Plausible.Site.t()) :: Date.t() | nil
  @doc """
  Returns the date of the first event of the given site, or `nil` if the site
  does not have stats yet.

  If this is the first time the function is called for the site, it queries
  Clickhouse and saves the date in the sites table.
  """
  def stats_start_date(site)

  def stats_start_date(%Site{stats_start_date: %Date{} = date}) do
    date
  end

  def stats_start_date(%Site{} = site) do
    if start_date = Plausible.Stats.Clickhouse.pageview_start_date_local(site) do
      updated_site =
        site
        |> Site.set_stats_start_date(start_date)
        |> Repo.update!()

      updated_site.stats_start_date
    end
  end

  def has_stats?(site) do
    !!stats_start_date(site)
  end

  def create_shared_link(site, name, password \\ nil) do
    changes =
      SharedLink.changeset(
        %SharedLink{
          site_id: site.id,
          slug: Nanoid.generate()
        },
        %{name: name, password: password}
      )

    Repo.insert(changes)
  end

  def shared_link_url(site, link) do
    base = PlausibleWeb.Endpoint.url()
    domain = "/share/#{URI.encode_www_form(site.domain)}"
    base <> domain <> "?auth=" <> link.slug
  end

  def get_for_user!(user_id, domain, roles \\ [:owner, :admin, :viewer]) do
    if :super_admin in roles and Plausible.Auth.is_super_admin?(user_id) do
      get_by_domain!(domain)
    else
      user_id
      |> get_for_user_q(domain, List.delete(roles, :super_admin))
      |> Repo.one!()
    end
  end

  def get_for_user(user_id, domain, roles \\ [:owner, :admin, :viewer]) do
    if :super_admin in roles and Plausible.Auth.is_super_admin?(user_id) do
      get_by_domain(domain)
    else
      user_id
      |> get_for_user_q(domain, List.delete(roles, :super_admin))
      |> Repo.one()
    end
  end

  defp get_for_user_q(user_id, domain, roles) do
    from(s in Site,
      join: sm in Site.Membership,
      on: sm.site_id == s.id,
      where: sm.user_id == ^user_id,
      where: sm.role in ^roles,
      where: s.domain == ^domain or s.domain_changed_from == ^domain,
      select: s
    )
  end

  def has_goals?(site) do
    Repo.exists?(
      from(g in Plausible.Goal,
        where: g.site_id == ^site.id
      )
    )
  end

  def is_member?(user_id, site) do
    role(user_id, site) !== nil
  end

  def has_admin_access?(user_id, site) do
    role(user_id, site) in [:admin, :owner]
  end

  def locked?(%Site{locked: locked}) do
    locked
  end

  def role(user_id, site) do
    Repo.one(
      from(sm in Site.Membership,
        where: sm.user_id == ^user_id and sm.site_id == ^site.id,
        select: sm.role
      )
    )
  end

  def owned_sites_count(user) do
    user
    |> owned_sites_query()
    |> Repo.aggregate(:count)
  end

  def owned_sites_domains(user) do
    user
    |> owned_sites_query()
    |> select([site], site.domain)
    |> Repo.all()
  end

  def owned_site_ids(user) do
    user
    |> owned_sites_query()
    |> select([site], site.id)
    |> Repo.all()
  end

  defp owned_sites_query(user) do
    from(s in Site,
      join: sm in Site.Membership,
      on: sm.site_id == s.id,
      where: sm.role == :owner,
      where: sm.user_id == ^user.id
    )
  end
end
