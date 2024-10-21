defmodule Plausible.Sites do
  @moduledoc """
  Sites context functions.
  """

  import Ecto.Query

  alias Plausible.Auth
  alias Plausible.Billing.Quota
  alias Plausible.Repo
  alias Plausible.Site
  alias Plausible.Site.SharedLink

  require Plausible.Site.UserPreference

  @type list_opt() :: {:filter_by_domain, String.t()}

  def get_by_domain(domain) do
    Repo.get_by(Site, domain: domain)
  end

  def get_by_domain!(domain) do
    Repo.get_by!(Site, domain: domain)
  end

  @spec toggle_pin(Auth.User.t(), Site.t()) ::
          {:ok, Site.UserPreference.t()} | {:error, :too_many_pins}
  def toggle_pin(user, site) do
    pinned_at =
      if site.pinned_at do
        nil
      else
        NaiveDateTime.utc_now()
      end

    with :ok <- check_user_pin_limit(user, pinned_at) do
      {:ok, set_option(user, site, :pinned_at, pinned_at)}
    end
  end

  @pins_limit 9

  defp check_user_pin_limit(_user, nil), do: :ok

  defp check_user_pin_limit(user, _) do
    pins_count =
      from(up in Site.UserPreference,
        where: up.user_id == ^user.id and not is_nil(up.pinned_at)
      )
      |> Repo.aggregate(:count)

    if pins_count + 1 > @pins_limit do
      {:error, :too_many_pins}
    else
      :ok
    end
  end

  @spec set_option(Auth.User.t(), Site.t(), atom(), any()) :: Site.UserPreference.t()
  def set_option(user, site, option, value) when option in Site.UserPreference.options() do
    get_for_user!(user.id, site.domain)

    user
    |> Site.UserPreference.changeset(site, %{option => value})
    |> Repo.insert!(
      conflict_target: [:user_id, :site_id],
      # This way of conflict handling enables doing upserts of options leaving
      # existing, unrelated values intact.
      on_conflict: from(p in Site.UserPreference, update: [set: [{^option, ^value}]]),
      returning: true
    )
  end

  @spec list(Auth.User.t(), map(), [list_opt()]) :: Scrivener.Page.t()
  def list(user, pagination_params, opts \\ []) do
    domain_filter = Keyword.get(opts, :filter_by_domain)

    from(s in Site,
      left_join: up in Site.UserPreference,
      on: up.site_id == s.id and up.user_id == ^user.id,
      inner_join: sm in assoc(s, :memberships),
      on: sm.user_id == ^user.id,
      select: %{
        s
        | pinned_at: selected_as(up.pinned_at, :pinned_at),
          entry_type:
            selected_as(
              fragment(
                """
                CASE
                  WHEN ? IS NOT NULL THEN 'pinned_site'
                  ELSE 'site'
                END
                """,
                up.pinned_at
              ),
              :entry_type
            )
      },
      order_by: [asc: selected_as(:entry_type), desc: selected_as(:pinned_at), asc: s.domain],
      preload: [memberships: sm]
    )
    |> maybe_filter_by_domain(domain_filter)
    |> Repo.paginate(pagination_params)
  end

  @spec list_with_invitations(Auth.User.t(), map(), [list_opt()]) :: Scrivener.Page.t()
  def list_with_invitations(user, pagination_params, opts \\ []) do
    domain_filter = Keyword.get(opts, :filter_by_domain)

    result =
      from(s in Site,
        left_join: up in Site.UserPreference,
        on: up.site_id == s.id and up.user_id == ^user.id,
        left_join: i in assoc(s, :invitations),
        on: i.email == ^user.email,
        left_join: sm in assoc(s, :memberships),
        on: sm.user_id == ^user.id,
        where: not is_nil(sm.id) or not is_nil(i.id),
        select: %{
          s
          | pinned_at: selected_as(up.pinned_at, :pinned_at),
            entry_type:
              selected_as(
                fragment(
                  """
                  CASE
                    WHEN ? IS NOT NULL THEN 'invitation'
                    WHEN ? IS NOT NULL THEN 'pinned_site'
                    ELSE 'site'
                  END
                  """,
                  i.id,
                  up.pinned_at
                ),
                :entry_type
              )
        },
        order_by: [asc: selected_as(:entry_type), desc: selected_as(:pinned_at), asc: s.domain],
        preload: [memberships: sm, invitations: i]
      )
      |> maybe_filter_by_domain(domain_filter)
      |> Repo.paginate(pagination_params)

    # Populating `site` preload on `invitation`
    # without requesting it from database.
    # Necessary for invitation modals logic.
    entries =
      Enum.map(result.entries, fn
        %{invitations: [invitation]} = site ->
          site = %{site | invitations: [], memberships: []}
          invitation = %{invitation | site: site}
          %{site | invitations: [invitation]}

        site ->
          site
      end)

    %{result | entries: entries}
  end

  @spec for_user_query(Auth.User.t()) :: Ecto.Query.t()
  def for_user_query(user) do
    from(s in Site,
      inner_join: sm in assoc(s, :memberships),
      on: sm.user_id == ^user.id,
      order_by: [desc: s.id]
    )
  end

  defp maybe_filter_by_domain(query, domain)
       when byte_size(domain) >= 1 and byte_size(domain) <= 64 do
    where(query, [s], ilike(s.domain, ^"%#{domain}%"))
  end

  defp maybe_filter_by_domain(query, _), do: query

  def create(user, params) do
    with :ok <- Quota.ensure_can_add_new_site(user) do
      Ecto.Multi.new()
      |> Ecto.Multi.put(:site_changeset, Site.new(params))
      |> Ecto.Multi.run(:create_team, fn _repo, _context ->
        Plausible.Teams.get_or_create(user)
      end)
      |> Ecto.Multi.run(:clear_changed_from, fn
        _repo, %{site_changeset: %{changes: %{domain: domain}}} ->
          case get_for_user(user.id, domain, [:owner]) do
            %Site{domain_changed_from: ^domain} = site ->
              site
              |> Ecto.Changeset.change()
              |> Ecto.Changeset.put_change(:domain_changed_from, nil)
              |> Ecto.Changeset.put_change(:domain_changed_at, nil)
              |> Repo.update()

            _ ->
              {:ok, :ignore}
          end

        _repo, _context ->
          {:ok, :ignore}
      end)
      |> Ecto.Multi.insert(:site, fn %{site_changeset: site, create_team: team} ->
        Ecto.Changeset.put_assoc(site, :team, team)
      end)
      |> Ecto.Multi.insert(:site_membership, fn %{site: site} ->
        Site.Membership.new(site, user)
      end)
      |> maybe_start_trial(user)
      |> Repo.transaction()
    end
  end

  defp maybe_start_trial(multi, user) do
    case user.trial_expiry_date do
      nil ->
        Ecto.Multi.run(multi, :user, fn _, _ ->
          {:ok, Plausible.Users.start_trial(user)}
        end)

      _ ->
        multi
    end
  end

  @spec clear_stats_start_date!(Site.t()) :: Site.t()
  def clear_stats_start_date!(site) do
    site
    |> Ecto.Changeset.change(stats_start_date: nil)
    |> Plausible.Repo.update!()
  end

  @spec stats_start_date(Site.t()) :: Date.t() | nil
  @doc """
  Returns the date of the first event of the given site, or `nil` if the site
  does not have stats yet.

  If this is the first time the function is called for the site, it queries
  imported stats and Clickhouse, choosing the earliest start date and saves
  it in the sites table.
  """
  def stats_start_date(site)

  def stats_start_date(%Site{stats_start_date: %Date{} = date}) do
    date
  end

  def stats_start_date(%Site{} = site) do
    site = Plausible.Imported.load_import_data(site)

    start_date =
      [
        site.earliest_import_start_date,
        native_stats_start_date(site)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.min(Date, fn -> nil end)

    if start_date do
      updated_site =
        site
        |> Site.set_stats_start_date(start_date)
        |> Repo.update!()

      updated_site.stats_start_date
    end
  end

  @spec native_stats_start_date(Site.t()) :: Date.t() | nil
  def native_stats_start_date(site) do
    Plausible.Stats.Clickhouse.pageview_start_date_local(site)
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

  @spec get_for_user!(Auth.User.t() | pos_integer(), String.t(), [
          :super_admin | :owner | :admin | :viewer
        ]) ::
          Site.t()
  def get_for_user!(user, domain, roles \\ [:owner, :admin, :viewer])

  def get_for_user!(%Auth.User{id: user_id}, domain, roles) do
    get_for_user!(user_id, domain, roles)
  end

  def get_for_user!(user_id, domain, roles) do
    if :super_admin in roles and Auth.is_super_admin?(user_id) do
      get_by_domain!(domain)
    else
      user_id
      |> get_for_user_q(domain, List.delete(roles, :super_admin))
      |> Repo.one!()
    end
  end

  @spec get_for_user(Auth.User.t() | pos_integer(), String.t(), [
          :super_admin | :owner | :admin | :viewer
        ]) ::
          Site.t() | nil
  def get_for_user(user, domain, roles \\ [:owner, :admin, :viewer])

  def get_for_user(%Auth.User{id: user_id}, domain, roles) do
    get_for_user(user_id, domain, roles)
  end

  def get_for_user(user_id, domain, roles) do
    if :super_admin in roles and Auth.is_super_admin?(user_id) do
      get_by_domain(domain)
    else
      user_id
      |> get_for_user_q(domain, List.delete(roles, :super_admin))
      |> Repo.one()
    end
  end

  def update_installation_meta!(site, meta) do
    site
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_change(:installation_meta, meta)
    |> Repo.update!()
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

  def owned_sites_locked?(user) do
    user
    |> owned_sites_query()
    |> where([s], s.locked == true)
    |> Repo.exists?()
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
