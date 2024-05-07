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

  defp maybe_filter_by_domain(query, domain)
       when byte_size(domain) >= 1 and byte_size(domain) <= 64 do
    where(query, [s], ilike(s.domain, ^"%#{domain}%"))
  end

  defp maybe_filter_by_domain(query, _), do: query

  def create(user, params) do
    with :ok <- Quota.ensure_can_add_new_site(user) do
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:site, Site.new(params))
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
        changeset = Auth.User.start_trial(user)
        Ecto.Multi.update(multi, :user, changeset)

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

  @doc """
  Returns the date of the first recorded stat in the timezone configured by the user.
  This function does 3 transformations:
    Date -> UTC DateTime at 00:00 -> Local %DateTime{} -> Local %Date

  ## Examples

    iex> %Plausible.Site{stats_start_date: nil} = site = Plausible.Factory.insert(:site)
    iex> Plausible.Sites.local_start_date(site)
    nil

    iex> site = %Plausible.Site{stats_start_date: ~D[2022-09-28], timezone: "Europe/Helsinki"}
    iex> Plausible.Sites.local_start_date(site)
    ~D[2022-09-28]

    iex> site = %Plausible.Site{stats_start_date: ~D[2022-09-28], timezone: "America/Los_Angeles"}
    iex> Plausible.Sites.local_start_date(site)
    ~D[2022-09-27]

  """
  @spec local_start_date(Site.t()) :: Date.t() | nil
  def local_start_date(site) do
    if stats_start_date = stats_start_date(site) do
      Plausible.Timezones.to_date_in_timezone(stats_start_date, site.timezone)
    end
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

  def get_for_user!(user_id, domain, roles \\ [:owner, :admin, :viewer]) do
    if :super_admin in roles and Auth.is_super_admin?(user_id) do
      get_by_domain!(domain)
    else
      user_id
      |> get_for_user_q(domain, List.delete(roles, :super_admin))
      |> Repo.one!()
    end
  end

  def get_for_user(user_id, domain, roles \\ [:owner, :admin, :viewer]) do
    if :super_admin in roles and Auth.is_super_admin?(user_id) do
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
