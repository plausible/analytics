defmodule Plausible.Sites do
  alias Plausible.{Repo, Site, Site.SharedLink, Auth.User, Billing.Quota}
  alias PlausibleWeb.Email
  import Ecto.Query

  @type invite_error() ::
          Ecto.Changeset.t()
          | :already_a_member
          | {:over_limit, non_neg_integer()}
          | :forbidden

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

  @spec bulk_transfer_ownership(
          [Site.t()],
          Plausible.Auth.User.t(),
          String.t(),
          Keyword.t()
        ) :: {:ok, [Plausible.Auth.Invitation.t()]} | {:error, invite_error()}
  def bulk_transfer_ownership(sites, inviter, invitee_email, opts \\ []) do
    Repo.transaction(fn ->
      for site <- sites do
        do_invite(site, inviter, invitee_email, :owner, opts)
      end
    end)
  end

  @spec invite(Site.t(), Plausible.Auth.User.t(), String.t(), atom()) ::
          {:ok, Plausible.Auth.Invitation.t()} | {:error, invite_error()}
  @doc """
  Invites a new team member to the given site. Returns a
  %Plausible.Auth.Invitation{} struct and sends the invitee an email to accept
  this invitation.

  The inviter must have enough permissions to invite the new team member,
  otherwise this function returns `{:error, :forbidden}`.

  If the new team member role is `:owner`, this function handles the invitation
  as an ownership transfer and requires the inviter to be the owner of the site.
  """
  def invite(site, inviter, invitee_email, role) do
    Repo.transaction(fn ->
      do_invite(site, inviter, invitee_email, role)
    end)
  end

  defp do_invite(site, inviter, invitee_email, role, opts \\ []) do
    attrs = %{email: invitee_email, role: role, site_id: site.id, inviter_id: inviter.id}

    with :ok <- check_invitation_permissions(site, inviter, role, opts),
         :ok <- check_team_member_limit(site, role),
         invitee <- Plausible.Auth.find_user_by(email: invitee_email),
         :ok <- ensure_new_membership(site, invitee, role),
         %Ecto.Changeset{} = changeset <- Plausible.Auth.Invitation.new(attrs),
         {:ok, invitation} <- Repo.insert(changeset) do
      send_invitation_email(invitation, invitee)
      invitation
    else
      {:error, cause} -> Repo.rollback(cause)
    end
  end

  defp check_invitation_permissions(site, inviter, requested_role, opts) do
    check_permissions? = Keyword.get(opts, :check_permissions, true)

    if check_permissions? do
      required_roles = if requested_role == :owner, do: [:owner], else: [:admin, :owner]

      membership_query =
        from(m in Plausible.Site.Membership,
          where: m.user_id == ^inviter.id and m.site_id == ^site.id and m.role in ^required_roles
        )

      if Repo.exists?(membership_query), do: :ok, else: {:error, :forbidden}
    else
      :ok
    end
  end

  defp send_invitation_email(invitation, invitee) do
    invitation = Repo.preload(invitation, [:site, :inviter])

    email =
      case {invitee, invitation.role} do
        {invitee, :owner} -> Email.ownership_transfer_request(invitation, invitee)
        {nil, _role} -> Email.new_user_invitation(invitation)
        {%User{}, _role} -> Email.existing_user_invitation(invitation)
      end

    Plausible.Mailer.send(email)
  end

  defp ensure_new_membership(_site, _invitee, :owner) do
    :ok
  end

  defp ensure_new_membership(site, invitee, _role) do
    if invitee && is_member?(invitee.id, site) do
      {:error, :already_a_member}
    else
      :ok
    end
  end

  defp check_team_member_limit(_site, :owner) do
    :ok
  end

  defp check_team_member_limit(site, _role) do
    site_owner = owner_for(site)
    limit = Quota.team_member_limit(site_owner)
    usage = Quota.team_member_usage(site_owner)

    if Quota.within_limit?(usage, limit),
      do: :ok,
      else: {:error, {:over_limit, limit}}
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

  def owner_for(site) do
    Repo.one(
      from(u in Plausible.Auth.User,
        join: sm in Site.Membership,
        on: sm.user_id == u.id,
        where: sm.site_id == ^site.id,
        where: sm.role == :owner
      )
    )
  end
end
