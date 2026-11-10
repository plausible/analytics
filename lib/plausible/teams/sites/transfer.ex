defmodule Plausible.Teams.Sites.Transfer do
  @moduledoc """
  Service for transferring sites.
  """

  alias Plausible.Auth
  alias Plausible.Billing
  alias Plausible.Repo
  alias Plausible.Site
  alias Plausible.Teams

  use Plausible

  import Ecto.Query, only: [from: 2]

  @type transfer_error() ::
          Billing.Quota.Limits.over_limits_error()
          | Ecto.Changeset.t()
          | :transfer_to_self
          | :no_plan
          | :multiple_teams
          | :permission_denied

  @doc """
  Creates a site transfer to the given email and sends the invitee
  an email to accept it. Only team owners and admins can do this.

  If a transfer of this site to this email already exists, the email is
  sent again with the existing transfer link. The transfer keeps its
  original expiry.

  Rejects if there's an existing guest invitation (not transfer) for
  this site and this email.
  """
  @spec initiate(Site.t(), Auth.User.t(), String.t()) ::
          {:ok, Teams.SiteTransfer.t()} | {:error, Ecto.Changeset.t() | :permission_denied}
  def initiate(site, initiator, invitee_email) do
    site = Repo.preload(site, :team)

    Repo.transaction(fn ->
      with :ok <- Teams.TeamRolePermissions.ensure_can_manage_team(site.team, initiator),
           {:ok, site_transfer} <-
             create_site_transfer(site, initiator, invitee_email) do
        invitee = Auth.find_user_by(email: invitee_email)

        site_transfer
        |> Repo.preload([:site, :initiator])
        |> send_transfer_request_email(invitee)

        site_transfer
      else
        {:error, cause} -> Repo.rollback(cause)
      end
    end)
  end

  @spec change_team(Site.t(), Auth.User.t(), Teams.Team.t()) ::
          :ok | {:error, transfer_error()}
  def change_team(site, user, new_team) do
    with {:ok, _} <- transfer_ownership(site, user, new_team) do
      send_team_changed_email(site, user, new_team)
      :ok
    end
  end

  @spec accept(Teams.SiteTransfer.t(), Auth.User.t(), Teams.Team.t() | nil, Keyword.t()) ::
          {:ok, %{team: Teams.Team.t(), team_memberships: [Teams.Membership.t()], site: Site.t()}}
          | {:error, transfer_error()}
  def accept(site_transfer, new_owner, team, opts \\ []) do
    site = Repo.preload(site_transfer.site, :team)

    with {:ok, new_team} <- maybe_get_team(new_owner, team),
         :ok <- ensure_transfer_valid(site.team, new_team),
         :ok <- Teams.TeamRolePermissions.ensure_can_manage_team(new_team, new_owner),
         :ok <- ensure_can_take_ownership(site, new_team, opts),
         :ok <- accept_site_transfer(site_transfer, new_team, opts) do
      send_transfer_accepted_email(site_transfer, new_team)

      site = site |> Repo.reload!() |> Repo.preload(ownerships: :user)

      {:ok, %{team: new_team, team_memberships: site.ownerships, site: site}}
    end
  end

  def ensure_can_take_ownership(site, team, opts \\ [])

  on_ee do
    def ensure_can_take_ownership(_site, nil, _opts), do: {:error, :no_plan}

    def ensure_can_take_ownership(site, team, opts) do
      team = Teams.with_subscription(team)
      plan = Billing.Plans.get_subscription_plan(team.subscription)
      active_subscription? = Billing.Subscriptions.active?(team.subscription)

      if active_subscription? and plan != :free_10k do
        team
        |> Teams.Billing.quota_usage(pending_ownership_site_ids: [site.id])
        |> Billing.Quota.ensure_within_plan_limits(plan,
          skip_site_limit_check?: Teams.Billing.grandfathered_team?(team),
          skip_team_member_limit_check?: opts[:skip_site_members_transfer?] == true
        )
      else
        {:error, :no_plan}
      end
    end
  else
    def ensure_can_take_ownership(_site, _team, _opts) do
      if always(true) do
        :ok
      else
        {:error, :no_plan}
      end
    end
  end

  defp transfer_ownership(site, new_owner, team) do
    site = Repo.preload(site, :team)

    with {:ok, new_team} <- maybe_get_team(new_owner, team),
         :ok <- ensure_transfer_valid(site.team, new_team),
         :ok <- Teams.TeamRolePermissions.ensure_can_manage_team(new_team, new_owner),
         :ok <- ensure_can_take_ownership(site, new_team),
         :ok <- transfer_site(site, new_team) do
      site = site |> Repo.reload!() |> Repo.preload(ownerships: :user)

      {:ok, site.ownerships}
    end
  end

  defp ensure_transfer_valid(team, new_team) do
    if team.id == new_team.id do
      {:error, :transfer_to_self}
    else
      :ok
    end
  end

  @doc """
  Creates a site transfer without sending any email. If a transfer of this
  site to this email already exists, returns it and sets its `updated_at`
  to `now`.
  """
  @spec create_site_transfer(Site.t(), Auth.User.t(), String.t(), NaiveDateTime.t()) ::
          {:ok, Teams.SiteTransfer.t()} | {:error, Ecto.Changeset.t()}
  def create_site_transfer(site, initiator, invitee_email, now \\ NaiveDateTime.utc_now(:second)) do
    changeset = Teams.SiteTransfer.changeset(site, initiator: initiator, email: invitee_email)

    if guest_invitation_exists?(site, invitee_email) do
      {:error, Ecto.Changeset.add_error(changeset, :invitation, "already sent")}
    else
      Repo.insert(changeset,
        on_conflict: [set: [updated_at: now]],
        conflict_target: [:email, :site_id],
        returning: true
      )
    end
  end

  defp guest_invitation_exists?(site, email) do
    Repo.exists?(
      from ti in Teams.Invitation,
        inner_join: gi in assoc(ti, :guest_invitations),
        where: ti.email == ^email,
        where: ti.team_id == ^site.team_id,
        where: gi.site_id == ^site.id
    )
  end

  defp accept_site_transfer(site_transfer, team, opts) do
    {:ok, _} =
      Repo.transaction(fn ->
        :ok =
          move_site_to_team(site_transfer.site, team, NaiveDateTime.utc_now(:second), opts)

        Repo.delete_all(from st in Teams.SiteTransfer, where: st.id == ^site_transfer.id)
      end)

    :ok
  end

  defp transfer_site(site, team) do
    {:ok, _} =
      Repo.transaction(fn ->
        :ok = move_site_to_team(site, team, NaiveDateTime.utc_now(:second))
      end)

    :ok
  end

  defp move_site_to_team(site, team, now, opts \\ []) do
    skip_site_members_transfer? = Keyword.get(opts, :skip_site_members_transfer?, false)

    site =
      Repo.preload(site, [
        :team,
        :owners,
        guest_memberships: [team_membership: :user],
        guest_invitations: [team_invitation: :inviter]
      ])

    prior_team = site.team

    site
    |> Ecto.Changeset.change(team_id: team.id)
    |> Repo.update!()

    old_guest_invitations = site.guest_invitations

    if not skip_site_members_transfer? do
      Enum.each(old_guest_invitations, fn old_guest_invitation ->
        recreate_guest_invitation(site, team, old_guest_invitation)
      end)
    end

    old_guest_ids = Enum.map(old_guest_invitations, & &1.id)
    Repo.delete_all(from gi in Teams.GuestInvitation, where: gi.id in ^old_guest_ids)
    :ok = Teams.Invitations.prune_guest_invitations(prior_team)

    old_guest_memberships = site.guest_memberships

    if not skip_site_members_transfer? do
      Enum.each(old_guest_memberships, fn old_guest_membership ->
        recreate_guest_membership(site, team, old_guest_membership, now)
      end)
    end

    old_guest_ids = Enum.map(old_guest_memberships, & &1.id)
    Repo.delete_all(from gm in Teams.GuestMembership, where: gm.id in ^old_guest_ids)
    :ok = Teams.Memberships.prune_guests(prior_team)

    if not skip_site_members_transfer? do
      add_prior_owners_as_site_editors(prior_team, team, site, now)
    end

    on_ee do
      Billing.SiteLocker.update_for(prior_team, send_email?: false)
      :unlocked = Billing.SiteLocker.update_for(team, send_email?: false)
      Plausible.ConsolidatedView.reset_if_enabled(prior_team)
    end

    :ok
  end

  defp recreate_guest_invitation(site, new_team, old_guest_invitation) do
    old_team_invitation = old_guest_invitation.team_invitation

    {:ok, new_team_invitation} =
      Teams.Invitations.create_team_invitation(
        new_team,
        old_team_invitation.email,
        old_team_invitation.inviter
      )

    {:ok, _new_guest_invitation} =
      Teams.Invitations.create_guest_invitation(
        new_team_invitation,
        site,
        old_guest_invitation.role
      )
  end

  defp recreate_guest_membership(site, new_team, old_guest_membership, now) do
    old_team_membership = old_guest_membership.team_membership

    {:ok, new_team_membership} =
      Teams.Invitations.create_team_membership(new_team, :guest, old_team_membership.user, now)

    if new_team_membership.role == :guest do
      {:ok, _} =
        new_team_membership
        |> Teams.GuestMembership.changeset(site, old_guest_membership.role)
        |> Repo.insert(
          on_conflict: [set: [updated_at: now, role: old_guest_membership.role]],
          conflict_target: [:team_membership_id, :site_id],
          returning: true
        )
    end
  end

  defp add_prior_owners_as_site_editors(prior_team, new_team, site, now) do
    prior_owners = Repo.preload(prior_team, :owners).owners

    for prior_owner <- prior_owners do
      {:ok, prior_owner_team_membership} =
        Teams.Invitations.create_team_membership(new_team, :guest, prior_owner, now)

      if prior_owner_team_membership.role == :guest do
        {:ok, _} =
          prior_owner_team_membership
          |> Teams.GuestMembership.changeset(site, :editor)
          |> Repo.insert(
            on_conflict: [set: [updated_at: now, role: :editor]],
            conflict_target: [:team_membership_id, :site_id],
            returning: true
          )
      end
    end
  end

  defp maybe_get_team(_user, %Teams.Team{} = team) do
    {:ok, team}
  end

  defp maybe_get_team(user, nil) do
    Teams.get_or_create(user)
  end

  defp send_transfer_request_email(site_transfer, invitee) do
    email =
      PlausibleWeb.Email.ownership_transfer_request(
        site_transfer.email,
        site_transfer.transfer_id,
        site_transfer.site,
        site_transfer.initiator,
        invitee
      )

    Plausible.Mailer.send(email)
  end

  defp send_transfer_accepted_email(site_transfer, team) do
    initiator_as_guest_editor? =
      Teams.Memberships.site_role(site_transfer.site, site_transfer.initiator) ==
        {:ok, {:guest_member, :editor}}

    PlausibleWeb.Email.ownership_transfer_accepted(
      site_transfer.email,
      site_transfer.initiator.email,
      team,
      site_transfer.site,
      initiator_as_guest_editor?
    )
    |> Plausible.Mailer.send()
  end

  defp send_team_changed_email(site, user, team) do
    owners = Repo.preload(team, :owners).owners

    for owner <- owners do
      PlausibleWeb.Email.team_changed(owner.email, user, team, site)
      |> Plausible.Mailer.send()
    end
  end
end
