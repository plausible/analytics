defmodule Plausible.Sites do
  @moduledoc """
  Sites context functions.
  """

  import Ecto.Query

  alias Plausible.Auth
  alias Plausible.Repo
  alias Plausible.Site
  alias Plausible.Teams
  alias Plausible.Site.SharedLink

  require Plausible.Site.UserPreference

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
    Plausible.Sites.get_for_user!(user, site.domain)

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
    owner_membership =
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
      |> Repo.one!()

    memberships =
      from(
        gm in Teams.GuestMembership,
        inner_join: tm in assoc(gm, :team_membership),
        inner_join: u in assoc(tm, :user),
        where: gm.site_id == ^site.id,
        select: %{
          user: u,
          role:
            fragment(
              """
              CASE
              WHEN ? = 'editor' THEN 'admin'
              ELSE ?
              END
              """,
              gm.role,
              gm.role
            )
        }
      )
      |> Repo.all()

    memberships = [owner_membership | memberships]

    invitations =
      from(
        gi in Teams.GuestInvitation,
        inner_join: ti in assoc(gi, :team_invitation),
        where: gi.site_id == ^site.id,
        select: %{
          invitation_id: gi.invitation_id,
          email: ti.email,
          role:
            fragment(
              """
              CASE
              WHEN ? = 'editor' THEN 'admin'
              ELSE ?
              END
              """,
              gi.role,
              gi.role
            )
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

  @spec for_user_query(Auth.User.t()) :: Ecto.Query.t()
  def for_user_query(user) do
    from(s in Site,
      inner_join: t in assoc(s, :team),
      inner_join: tm in assoc(t, :team_memberships),
      left_join: gm in assoc(tm, :guest_memberships),
      where: tm.user_id == ^user.id,
      where: tm.role != :guest or gm.site_id == s.id,
      order_by: [desc: s.id]
    )
  end

  def create(user, params) do
    Ecto.Multi.new()
    |> Ecto.Multi.put(:site_changeset, Site.new(params))
    |> Ecto.Multi.run(:create_team, fn _repo, _context ->
      {:ok, team} = Plausible.Teams.get_or_create(user)

      {:ok, Plausible.Teams.with_subscription(team)}
    end)
    |> Ecto.Multi.run(:ensure_can_add_new_site, fn _repo, %{create_team: team} ->
      case Plausible.Teams.Billing.ensure_can_add_new_site(team) do
        :ok -> {:ok, :proceed}
        error -> error
      end
    end)
    |> Ecto.Multi.run(:clear_changed_from, fn
      _repo, %{site_changeset: %{changes: %{domain: domain}}} ->
        case Plausible.Sites.get_for_user(user, domain, [:owner]) do
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

  def update_installation_meta!(site, meta) do
    site
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_change(:installation_meta, meta)
    |> Repo.update!()
  end

  def maybe_enable_engagement_metrics(site) do
    if is_nil(site.engagement_metrics_enabled_at) and
         Plausible.Stats.Clickhouse.has_pageleaves_last_30d?(site) do
      set_engagement_metrics_enabled_at(site)
    else
      {:ok, site}
    end
  end

  def set_engagement_metrics_enabled_at(site) do
    utc_now = NaiveDateTime.utc_now(:second)

    site
    |> Ecto.Changeset.change(%{engagement_metrics_enabled_at: utc_now})
    |> Repo.update()
  end

  def has_engagement_metrics?(site) do
    not is_nil(site.engagement_metrics_enabled_at)
  end

  def has_goals?(site) do
    Repo.exists?(
      from(g in Plausible.Goal,
        where: g.site_id == ^site.id
      )
    )
  end

  def locked?(%Site{locked: locked}) do
    locked
  end

  def get_for_user!(user, domain, roles \\ [:owner, :admin, :viewer]) do
    roles = translate_roles(roles)

    site =
      if :super_admin in roles and Plausible.Auth.is_super_admin?(user.id) do
        get_by_domain!(domain)
      else
        user.id
        |> get_for_user_query(domain, List.delete(roles, :super_admin))
        |> Repo.one!()
      end

    Repo.preload(site, :team)
  end

  def get_for_user(user, domain, roles \\ [:owner, :admin, :viewer]) do
    roles = translate_roles(roles)

    if :super_admin in roles and Plausible.Auth.is_super_admin?(user.id) do
      get_by_domain(domain)
    else
      user.id
      |> get_for_user_query(domain, List.delete(roles, :super_admin))
      |> Repo.one()
    end
  end

  defp translate_roles(roles) do
    Enum.map(roles, fn
      :admin -> :editor
      role -> role
    end)
  end

  defp get_for_user_query(user_id, domain, roles) do
    roles = Enum.map(roles, &to_string/1)

    from(s in Plausible.Site,
      join: t in assoc(s, :team),
      join: tm in assoc(t, :team_memberships),
      left_join: gm in assoc(tm, :guest_memberships),
      where: tm.user_id == ^user_id,
      where: coalesce(gm.role, tm.role) in ^roles,
      where: s.domain == ^domain or s.domain_changed_from == ^domain,
      where: is_nil(gm.id) or gm.site_id == s.id,
      select: s
    )
  end
end
