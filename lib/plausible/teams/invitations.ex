defmodule Plausible.Teams.Invitations do
  @moduledoc false

  import Ecto.Query

  alias Plausible.Billing
  alias Plausible.Repo
  alias Plausible.Teams

  def invite_sync(site, site_invitation) do
    site = Teams.load_for_site(site)
    site_invitation = Repo.preload(site_invitation, :inviter)
    role = translate_role(site_invitation.role)

    if site_invitation.role == :owner do
      {:ok, site_transfer} =
        create_site_transfer(
          site,
          site_invitation.inviter,
          site_invitation.email
        )

      site_transfer
      |> Ecto.Changeset.change(transfer_id: site_invitation.invitation_id)
      |> Repo.update!()
    else
      {:ok, guest_invitation} =
        create_invitation(
          site,
          site_invitation.email,
          role,
          site_invitation.inviter
        )

      guest_invitation
      |> Ecto.Changeset.change(invitation_id: site_invitation.invitation_id)
      |> Repo.update!()
    end
  end

  def remove_invitation_sync(site_invitation) do
    site = Repo.preload(site_invitation, :site).site
    site = Teams.load_for_site(site)

    if site_invitation.role == :owner do
      Repo.delete_all(
        from(
          st in Teams.SiteTransfer,
          where: st.email == ^site_invitation.email,
          where: st.site_id == ^site.id
        )
      )
    else
      Repo.delete_all(
        from(
          gi in Teams.GuestInvitation,
          inner_join: ti in assoc(gi, :team_invitation),
          where: ti.email == ^site_invitation.email,
          where: gi.site_id == ^site.id
        )
      )

      prune_guest_invitations(site.team)
    end

    :ok
  end

  def transfer_site_sync(site, user) do
    {:ok, team} = Teams.get_or_create(user)
    site = Teams.load_for_site(site)

    site =
      Repo.preload(site, [
        :team,
        :owner,
        guest_memberships: [team_membership: :user],
        guest_invitations: [team_invitation: :inviter]
      ])

    {:ok, _} =
      Repo.transaction(fn ->
        :ok = transfer_site_ownership(site, team, NaiveDateTime.utc_now(:second))
      end)
  end

  def accept_invitation_sync(site_invitation, user) do
    site_invitation =
      Repo.preload(
        site_invitation,
        site: :team
      )

    site = Teams.load_for_site(site_invitation.site)
    site_invitation = %{site_invitation | site: site}

    role =
      case site_invitation.role do
        :viewer -> :viewer
        :admin -> :editor
      end

    {:ok, guest_invitation} =
      create_invitation(
        site_invitation.site,
        site_invitation.email,
        role,
        site_invitation.inviter
      )

    team_invitation =
      guest_invitation.team_invitation
      |> Repo.preload([
        :team,
        :inviter,
        guest_invitations: :site
      ])

    {:ok, _} =
      result =
      do_accept(team_invitation, user, NaiveDateTime.utc_now(:second),
        send_email?: false,
        guest_invitations: [guest_invitation]
      )

    prune_guest_invitations(team_invitation.team)
    result
  end

  def accept_transfer_sync(site_invitation, user) do
    {:ok, team} = Teams.get_or_create(user)

    site =
      site_invitation.site
      |> Teams.load_for_site()
      |> Repo.preload([
        :team,
        :owner,
        guest_memberships: [team_membership: :user],
        guest_invitations: [team_invitation: :inviter]
      ])

    {:ok, site_transfer} =
      create_site_transfer(site, site_invitation.inviter, site_invitation.email)

    {:ok, _} =
      Repo.transaction(fn ->
        :ok = transfer_site_ownership(site, team, NaiveDateTime.utc_now(:second))
        Repo.delete!(site_transfer)
      end)
  end

  def check_transfer_permissions(_team, _initiator, false = _check_permissions?) do
    :ok
  end

  def check_transfer_permissions(team, initiator, _) do
    case Teams.Memberships.team_role(team, initiator) do
      {:ok, :owner} -> :ok
      _ -> {:error, :forbidden}
    end
  end

  @doc false
  def ensure_transfer_valid(_team, nil, :owner), do: :ok

  def ensure_transfer_valid(team, new_owner, :owner) do
    case Teams.Memberships.team_role(team, new_owner) do
      {:ok, :owner} -> {:error, :transfer_to_self}
      _ -> :ok
    end
  end

  def ensure_transfer_valid(_team, _new_owner, _role), do: :ok

  defp create_site_transfer(site, initiator, invitee_email, now \\ NaiveDateTime.utc_now(:second)) do
    site
    |> Teams.SiteTransfer.changeset(initiator: initiator, email: invitee_email)
    |> Repo.insert(
      on_conflict: [set: [updated_at: now]],
      conflict_target: [:email, :site_id],
      returning: true
    )
  end

  def send_transfer_init_email(site_transfer, new_owner) do
    email =
      PlausibleWeb.Email.ownership_transfer_request(
        site_transfer.email,
        site_transfer.transfer_id,
        site_transfer.site,
        site_transfer.initiator,
        new_owner
      )

    Plausible.Mailer.send(email)
  end

  defp do_accept(team_invitation, user, now, opts) do
    send_email? = Keyword.get(opts, :send_email?, true)
    guest_invitations = Keyword.get(opts, :guest_invitations, team_invitation.guest_invitations)

    Repo.transaction(fn ->
      with {:ok, team_membership} <-
             create_team_membership(team_invitation.team, team_invitation.role, user, now),
           {:ok, _guest_memberships} <-
             create_guest_memberships(team_membership, guest_invitations, now) do
        # Clean up guest invitations after accepting
        guest_invitation_ids = Enum.map(guest_invitations, & &1.id)
        Repo.delete_all(from gi in Teams.GuestInvitation, where: gi.id in ^guest_invitation_ids)
        prune_guest_invitations(team_invitation.team)

        if send_email? do
          send_invitation_accepted_email(team_invitation, guest_invitations)
        end

        team_membership
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp transfer_site_ownership(site, team, now) do
    prior_team = site.team

    site
    |> Ecto.Changeset.change(team_id: team.id)
    |> Repo.update!()

    {_old_team_invitations, old_guest_invitations} =
      site.guest_invitations
      |> Enum.map(fn old_guest_invitation ->
        old_team_invitation = old_guest_invitation.team_invitation

        {:ok, new_team_invitation} =
          create_team_invitation(team, old_team_invitation.email, old_team_invitation.inviter)

        {:ok, _new_guest_invitation} =
          create_guest_invitation(new_team_invitation, site, old_guest_invitation.role)

        {old_team_invitation, old_guest_invitation}
      end)
      |> Enum.unzip()

    old_guest_ids = Enum.map(old_guest_invitations, & &1.id)
    Repo.delete_all(from gi in Teams.GuestInvitation, where: gi.id in ^old_guest_ids)
    :ok = prune_guest_invitations(prior_team)

    {_old_team_memberships, old_guest_memberships} =
      site.guest_memberships
      |> Enum.map(fn old_guest_membership ->
        old_team_membership = old_guest_membership.team_membership

        {:ok, new_team_membership} =
          create_team_membership(team, :guest, old_team_membership.user, now)

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

        {old_team_membership, old_guest_membership}
      end)
      |> Enum.unzip()

    old_guest_ids = Enum.map(old_guest_memberships, & &1.id)
    Repo.delete_all(from gm in Teams.GuestMembership, where: gm.id in ^old_guest_ids)
    :ok = Teams.Memberships.prune_guests(prior_team)

    {:ok, prior_owner} = Teams.Sites.get_owner(prior_team)

    {:ok, prior_owner_team_membership} = create_team_membership(team, :guest, prior_owner, now)

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

    :ok
  end

  def prune_guest_invitations(team) do
    guest_query =
      from(
        gi in Teams.GuestInvitation,
        where: gi.team_invitation_id == parent_as(:team_invitation).id,
        select: true
      )

    Repo.delete_all(
      from(
        ti in Teams.Invitation,
        as: :team_invitation,
        where: ti.team_id == ^team.id and ti.role == :guest,
        where: not exists(guest_query)
      )
    )

    :ok
  end

  def ensure_can_take_ownership(_site, nil), do: {:error, :no_plan}

  def ensure_can_take_ownership(site, team) do
    team = Teams.with_subscription(team)
    plan = Billing.Plans.get_subscription_plan(team.subscription)
    active_subscription? = Billing.Subscriptions.active?(team.subscription)

    if active_subscription? and plan != :free_10k do
      team
      |> Teams.Billing.quota_usage(pending_ownership_site_ids: [site.id])
      |> Billing.Quota.ensure_within_plan_limits(plan)
    else
      {:error, :no_plan}
    end
  end

  def send_transfer_accepted_email(site_transfer) do
    PlausibleWeb.Email.ownership_transfer_accepted(
      site_transfer.email,
      site_transfer.initiator.email,
      site_transfer.site
    )
    |> Plausible.Mailer.send()
  end

  @doc false
  def check_invitation_permissions(site, inviter, invitation_role, opts) do
    check_permissions? = Keyword.get(opts, :check_permissions, true)

    if check_permissions? do
      case Teams.Memberships.site_role(site, inviter) do
        {:ok, :owner} when invitation_role == :owner ->
          :ok

        {:ok, inviter_role}
        when inviter_role in [:owner, :editor, :admin] and invitation_role != :owner ->
          :ok

        _ ->
          {:error, :forbidden}
      end
    else
      :ok
    end
  end

  defp translate_role(:admin), do: :editor
  defp translate_role(role), do: role

  @doc false
  def check_team_member_limit(_team, :owner, _invitee_email), do: :ok

  def check_team_member_limit(team, _role, invitee_email) do
    limit = Teams.Billing.team_member_limit(team)
    usage = Teams.Billing.team_member_usage(team, exclude_emails: [invitee_email])

    if Billing.Quota.below_limit?(usage, limit) do
      :ok
    else
      {:error, {:over_limit, limit}}
    end
  end

  @doc false
  def ensure_new_membership(_site, nil, _role), do: :ok

  def ensure_new_membership(_site, _invitee, :owner), do: :ok

  def ensure_new_membership(site, invitee, _role) do
    if Teams.Memberships.site_role(site, invitee) == {:error, :not_a_member} do
      :ok
    else
      {:error, :already_a_member}
    end
  end

  defp create_invitation(site, invitee_email, role, inviter) do
    Repo.transaction(fn ->
      with {:ok, team_invitation} <- create_team_invitation(site.team, invitee_email, inviter),
           {:ok, guest_invitation} <- create_guest_invitation(team_invitation, site, role) do
        guest_invitation
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp create_team_invitation(team, invitee_email, inviter) do
    now = NaiveDateTime.utc_now(:second)

    team
    |> Teams.Invitation.changeset(email: invitee_email, role: :guest, inviter: inviter)
    |> Repo.insert(
      on_conflict: [set: [updated_at: now]],
      conflict_target: [:team_id, :email],
      returning: true
    )
  end

  defp create_guest_invitation(team_invitation, site, role) do
    now = NaiveDateTime.utc_now(:second)

    team_invitation
    |> Teams.GuestInvitation.changeset(site, role)
    |> Repo.insert(
      on_conflict: [set: [updated_at: now]],
      conflict_target: [:team_invitation_id, :site_id],
      returning: true
    )
  end

  @doc false
  def send_invitation_email(%Teams.SiteTransfer{} = transfer, invitee) do
    email =
      PlausibleWeb.Email.ownership_transfer_request(
        transfer.email,
        transfer.transfer_id,
        transfer.site,
        transfer.initiator,
        invitee
      )

    Plausible.Mailer.send(email)
  end

  def send_invitation_email(%Teams.GuestInvitation{} = guest_invitation, invitee) do
    team_invitation = guest_invitation.team_invitation

    email =
      if invitee do
        PlausibleWeb.Email.existing_user_invitation(
          team_invitation.email,
          guest_invitation.site,
          team_invitation.inviter
        )
      else
        PlausibleWeb.Email.new_user_invitation(
          team_invitation.email,
          guest_invitation.invitation_id,
          guest_invitation.site,
          team_invitation.inviter
        )
      end

    Plausible.Mailer.send(email)
  end

  defp create_team_membership(team, role, user, now) do
    team
    |> Teams.Membership.changeset(user, role)
    |> Repo.insert(
      on_conflict: [set: [updated_at: now]],
      conflict_target: [:team_id, :user_id],
      returning: true
    )
  end

  defp create_guest_memberships(_team_membership, [], _now) do
    {:ok, []}
  end

  defp create_guest_memberships(%{role: role} = _team_membership, _, _) when role != :guest do
    {:ok, []}
  end

  defp create_guest_memberships(team_membership, guest_invitations, now) do
    Enum.reduce_while(guest_invitations, {:ok, []}, fn guest_invitation,
                                                       {:ok, guest_memberships} ->
      result =
        team_membership
        |> Teams.GuestMembership.changeset(guest_invitation.site, guest_invitation.role)
        |> Repo.insert(
          on_conflict: [set: [updated_at: now]],
          conflict_target: [:team_membership_id, :site_id]
        )

      case result do
        {:ok, guest_membership} -> {:cont, {:ok, [guest_membership | guest_memberships]}}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
  end

  defp send_invitation_accepted_email(_team_invitation, []) do
    # NOOP for now
    :ok
  end

  defp send_invitation_accepted_email(team_invitation, [guest_invitation | _]) do
    team_invitation.inviter.email
    |> PlausibleWeb.Email.invitation_accepted(team_invitation.email, guest_invitation.site)
    |> Plausible.Mailer.send()
  end
end
