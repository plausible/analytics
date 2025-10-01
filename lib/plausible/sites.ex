defmodule Plausible.Sites do
  @moduledoc """
  Sites context functions.
  """
  use Plausible

  import Ecto.Query

  alias Plausible.{Auth, Repo, Site, Teams, Billing}
  alias Plausible.Billing.Feature.SharedLinks
  alias Plausible.Site.SharedLink

  require Plausible.Site.UserPreference

  on_ee do
    @spec regular?(Site.t()) :: boolean()
    def regular?(%Site{} = site), do: not site.consolidated

    @spec consolidated?(Site.t()) :: boolean()
    def consolidated?(%Site{} = site), do: site.consolidated
  else
    @spec regular?(Site.t()) :: boolean()
    def regular?(%Site{}), do: true

    @spec consolidated?(Site.t()) :: boolean()
    def consolidated?(%Site{}), do: false
  end

  @shared_link_special_names ["WordPress - Shared Dashboard"]
  @doc """
  Special shared link names are used to distinguish between those
  created by the Plugins API, and those created in any other way
  (i.e. via Sites API or in the Dashboard Site Settings UI).

  The intent is to give our WP plugin the ability to display an
  embedded dashboard even when the user's subscription does not
  support the shared links feature.

  A shared link with a special name can only be created via the
  plugins API, and it will not show up under the list of shared
  links in Site Settings > Visibility.

  Once created with the special name, the link will be accessible
  even when the team does not have access to SharedLinks feature.
  """
  def shared_link_special_names(), do: @shared_link_special_names

  def get_by_domain(domain, opts \\ []) do
    include_consolidated? = Keyword.get(opts, :include_consolidated?, false)

    if include_consolidated? do
      Repo.get_by(Site, domain: domain)
    else
      Repo.get_by(Site.regular(), domain: domain)
    end
  end

  def get_by_domain!(domain, opts \\ []) do
    include_consolidated? = Keyword.get(opts, :include_consolidated?, false)

    if include_consolidated? do
      Repo.get_by!(Site, domain: domain)
    else
      Repo.get_by!(Site.regular(), domain: domain)
    end
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
    get_for_user!(user, site.domain)

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

  defdelegate list(user, pagination_params, opts \\ []), to: Plausible.Teams.Sites

  defdelegate list_with_invitations(user, pagination_params, opts \\ []),
    to: Plausible.Teams.Sites

  def list_people(site) do
    owner_memberships =
      from(
        tm in Teams.Membership,
        inner_join: u in assoc(tm, :user),
        where: tm.team_id == ^site.team_id,
        where: tm.role == :owner,
        select: %{
          user: u,
          role: tm.role
        }
      )
      |> Repo.all()

    memberships =
      from(
        gm in Teams.GuestMembership,
        inner_join: tm in assoc(gm, :team_membership),
        inner_join: u in assoc(tm, :user),
        where: gm.site_id == ^site.id,
        select: %{
          user: u,
          role: gm.role
        }
      )
      |> Repo.all()

    memberships = owner_memberships ++ memberships

    invitations =
      from(
        gi in Teams.GuestInvitation,
        inner_join: ti in assoc(gi, :team_invitation),
        where: gi.site_id == ^site.id,
        select: %{
          invitation_id: gi.invitation_id,
          email: ti.email,
          role: gi.role
        }
      )
      |> Repo.all()

    site_transfers =
      from(
        st in Teams.SiteTransfer,
        where: st.site_id == ^site.id,
        select: %{
          invitation_id: st.transfer_id,
          email: st.email,
          role: :owner
        }
      )
      |> Repo.all()

    %{memberships: memberships, invitations: site_transfers ++ invitations}
  end

  @spec list_guests_query(Site.t(), Keyword.t()) :: Ecto.Query.t()
  def list_guests_query(site, opts \\ []) do
    guest_memberships =
      from(
        gm in Teams.GuestMembership,
        inner_join: tm in assoc(gm, :team_membership),
        inner_join: u in assoc(tm, :user),
        as: :user,
        where: gm.site_id == ^site.id,
        select: %{
          id: gm.id,
          inserted_at: gm.inserted_at,
          email: u.email,
          role: gm.role,
          status: "accepted"
        }
      )

    guest_memberships =
      if email = opts[:email] do
        guest_memberships |> where([user: u], u.email == ^email)
      else
        guest_memberships
      end

    guest_invitations =
      from(
        gi in Teams.GuestInvitation,
        inner_join: ti in assoc(gi, :team_invitation),
        as: :team_invitation,
        where: gi.site_id == ^site.id,
        select: %{
          id: gi.id,
          inserted_at: gi.inserted_at,
          email: ti.email,
          role: gi.role,
          status: "invited"
        }
      )

    guest_invitations =
      if email = opts[:email] do
        guest_invitations |> where([team_invitation: ti], ti.email == ^email)
      else
        guest_invitations
      end

    guests = union_all(guest_memberships, ^guest_invitations)

    from(g in subquery(guests),
      select: %{
        id: g.id,
        inserted_at: g.inserted_at,
        email: g.email,
        role: g.role,
        status: g.status
      },
      order_by: [desc: g.inserted_at, desc: g.id]
    )
  end

  @spec for_user_query(Auth.User.t(), Teams.Team.t() | nil) :: Ecto.Query.t()
  def for_user_query(user, team \\ nil) do
    query =
      from(s in Site.regular(),
        as: :site,
        inner_join: t in assoc(s, :team),
        as: :team,
        inner_join: tm in assoc(t, :team_memberships),
        as: :team_memberships,
        left_join: gm in assoc(tm, :guest_memberships),
        as: :guest_memberships,
        where: tm.user_id == ^user.id,
        order_by: [desc: s.id]
      )

    if team do
      where(
        query,
        [team_memberships: tm, guest_memberships: gm, site: s],
        tm.role != :guest and tm.team_id == ^team.id
      )
    else
      where(
        query,
        [team_memberships: tm, guest_memberships: gm, site: s],
        tm.role != :guest or gm.site_id == s.id
      )
    end
  end

  def create(user, params, team \\ nil) do
    Ecto.Multi.new()
    |> Ecto.Multi.put(:site_changeset, Site.new(params))
    |> Ecto.Multi.run(:create_team, fn _repo, _context ->
      cond do
        team && Teams.Memberships.can_add_site?(team, user) ->
          {:ok, Teams.with_subscription(team)}

        is_nil(team) ->
          with {:ok, team} <- Teams.get_or_create(user) do
            {:ok, Teams.with_subscription(team)}
          end

        true ->
          {:error, :permission_denied}
      end
    end)
    |> Ecto.Multi.run(:ensure_can_add_new_site, fn _repo, %{create_team: team} ->
      case Teams.Billing.ensure_can_add_new_site(team) do
        :ok -> {:ok, :proceed}
        error -> error
      end
    end)
    |> Ecto.Multi.run(:clear_changed_from, fn
      _repo, %{site_changeset: %{changes: %{domain: domain}}} ->
        case get_for_user(user, domain, roles: [:owner]) do
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
    |> Ecto.Multi.run(:trial, fn _repo, %{create_team: team} ->
      if is_nil(team.trial_expiry_date) and is_nil(team.subscription) do
        Teams.start_trial(team)
        {:ok, :trial_started}
      else
        {:ok, :trial_already_started}
      end
    end)
    |> Ecto.Multi.run(:updated_lock, fn _repo, %{create_team: team} ->
      lock_state =
        if ee?() do
          Billing.SiteLocker.update_for(team, send_email?: false)
        else
          :unlocked
        end

      {:ok, lock_state}
    end)
    |> Repo.transaction()
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

  on_ee do
    # for now, we're going to always update consolidated views
    def stats_start_date(%Site{consolidated: true} = site) do
      team = Repo.preload(site, :team).team

      site
      |> Plausible.ConsolidatedView.change_stats_dates(team)
      |> Repo.update!()
      |> Map.fetch!(:stats_start_date)
    end
  end

  def stats_start_date(%Site{stats_start_date: %Date{} = date}) do
    date
  end

  def stats_start_date(%Site{} = site) do
    start_date =
      [
        Plausible.Imported.earliest_import_start_date(site),
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

  def create_shared_link(site, name, opts \\ []) do
    password = Keyword.get(opts, :password)
    site = Plausible.Repo.preload(site, :team)
    skip_feature_check? = Keyword.get(opts, :skip_feature_check?, false)

    if not skip_feature_check? and SharedLinks.check_availability(site.team) != :ok do
      {:error, :upgrade_required}
    else
      %SharedLink{site_id: site.id, slug: Nanoid.generate()}
      |> SharedLink.changeset(
        %{name: name, password: password},
        Keyword.take(opts, [:skip_special_name_check?])
      )
      |> Repo.insert()
    end
  end

  def shared_link_url(site, link) do
    base = PlausibleWeb.Endpoint.url()
    domain = "/share/#{URI.encode_www_form(site.domain)}"
    base <> domain <> "?auth=" <> link.slug
  end

  def update_legacy_time_on_page_cutoff!(site, cutoff) do
    site
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_change(:legacy_time_on_page_cutoff, cutoff)
    |> Repo.update!()
  end

  def has_goals?(site) do
    Repo.exists?(
      from(g in Plausible.Goal,
        where: g.site_id == ^site.id
      )
    )
  end

  def get_for_user!(user, domain, opts \\ []) do
    opts = default_get_for_user_opts(opts)
    roles = Keyword.fetch!(opts, :roles)
    include_consolidated? = Keyword.fetch!(opts, :include_consolidated?)

    site =
      if :super_admin in roles and Plausible.Auth.is_super_admin?(user.id) do
        get_by_domain!(domain, include_consolidated?: include_consolidated?)
      else
        user.id
        |> get_for_user_query(domain, List.delete(roles, :super_admin), opts)
        |> Repo.one!()
      end

    Repo.preload(site, :team)
  end

  def get_for_user(user, domain, opts \\ []) do
    opts = default_get_for_user_opts(opts)
    roles = Keyword.fetch!(opts, :roles)
    include_consolidated? = Keyword.fetch!(opts, :include_consolidated?)

    if :super_admin in roles and Plausible.Auth.is_super_admin?(user.id) do
      get_by_domain(domain, include_consolidated?: include_consolidated?)
    else
      user.id
      |> get_for_user_query(domain, List.delete(roles, :super_admin), opts)
      |> Repo.one()
    end
  end

  defp get_for_user_query(user_id, domain, roles, opts) do
    include_consolidated? = Keyword.fetch!(opts, :include_consolidated?)
    roles = Enum.map(roles, &to_string/1)

    q =
      from(s in Site,
        join: t in assoc(s, :team),
        join: tm in assoc(t, :team_memberships),
        left_join: gm in assoc(tm, :guest_memberships),
        where: tm.user_id == ^user_id,
        where: coalesce(gm.role, tm.role) in ^roles,
        where: s.domain == ^domain or s.domain_changed_from == ^domain,
        where: is_nil(gm.id) or gm.site_id == s.id,
        select: s
      )

    if include_consolidated? do
      q
    else
      from(s in Site.regular(q))
    end
  end

  defp default_get_for_user_opts(opts) do
    Keyword.merge(
      [include_consolidated?: false, roles: [:owner, :admin, :editor, :viewer]],
      opts
    )
  end
end
