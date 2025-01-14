defmodule Plausible.Teams.Invitations do
  @moduledoc false

  use Plausible

  import Ecto.Query

  alias Plausible.Billing
  alias Plausible.Repo
  alias Plausible.Teams

  def find_for_user(invitation_or_transfer_id, user) do
    with {:error, :invitation_not_found} <-
           find_team_invitation_for_user(invitation_or_transfer_id, user),
         {:error, :invitation_not_found} <-
           find_guest_invitation_for_user(invitation_or_transfer_id, user) do
      find_transfer_for_user(invitation_or_transfer_id, user)
    end
  end

  def find_for_site(invitation_or_transfer_id, site) do
    with {:error, :invitation_not_found} <-
           find_invitation_for_site(invitation_or_transfer_id, site) do
      find_transfer_for_site(invitation_or_transfer_id, site)
    end
  end

  defp find_team_invitation_for_user(team_invitation_id, user) do
    invitation_query =
      from ti in Teams.Invitation,
        inner_join: inviter in assoc(ti, :inviter),
        inner_join: team in assoc(ti, :team),
        where: ti.invitation_id == ^team_invitation_id,
        where: ti.email == ^user.email,
        where: ti.role != :guest,
        preload: [inviter: inviter, team: team]

    case Repo.one(invitation_query) do
      nil ->
        {:error, :invitation_not_found}

      invitation ->
        {:ok, invitation}
    end
  end

  defp find_guest_invitation_for_user(guest_invitation_id, user) do
    invitation_query =
      from gi in Teams.GuestInvitation,
        inner_join: s in assoc(gi, :site),
        inner_join: ti in assoc(gi, :team_invitation),
        inner_join: inviter in assoc(ti, :inviter),
        where: gi.invitation_id == ^guest_invitation_id,
        where: ti.email == ^user.email,
        preload: [site: s, team_invitation: {ti, inviter: inviter}]

    case Repo.one(invitation_query) do
      nil ->
        {:error, :invitation_not_found}

      invitation ->
        {:ok, invitation}
    end
  end

  defp find_transfer_for_user(transfer_id, user) do
    transfer =
      Teams.SiteTransfer
      |> Repo.get_by(transfer_id: transfer_id, email: user.email)
      |> Repo.preload([:site, :initiator])

    case transfer do
      nil ->
        {:error, :invitation_not_found}

      transfer ->
        {:ok, transfer}
    end
  end

  defp find_invitation_for_site(guest_invitation_id, site) do
    invitation =
      Teams.GuestInvitation
      |> Repo.get_by(invitation_id: guest_invitation_id, site_id: site.id)
      |> Repo.preload([:site, team_invitation: :inviter])

    case invitation do
      nil ->
        {:error, :invitation_not_found}

      invitation ->
        {:ok, invitation}
    end
  end

  defp find_transfer_for_site(transfer_id, site) do
    transfer =
      Teams.SiteTransfer
      |> Repo.get_by(transfer_id: transfer_id, site_id: site.id)
      |> Repo.preload([:site, :initiator])

    case transfer do
      nil ->
        {:error, :invitation_not_found}

      transfer ->
        {:ok, transfer}
    end
  end

  def invite(%Teams.Team{} = team, invitee_email, role, inviter) do
    create_team_invitation(team, invitee_email, inviter, role: role)
  end

  def invite(%Plausible.Site{} = site, invitee_email, role, inviter) do
    site = Teams.load_for_site(site)

    if role == :owner do
      create_site_transfer(
        site,
        inviter,
        invitee_email
      )
    else
      create_invitation(
        site,
        invitee_email,
        role,
        inviter
      )
    end
  end

  def remove_team_invitation(team_invitation) do
    Repo.delete_all(
      from ti in Teams.Invitation,
        where: ti.id == ^team_invitation.id
    )

    :ok
  end

  def remove_guest_invitation(guest_invitation) do
    site = Repo.preload(guest_invitation, site: :team).site

    Repo.delete_all(
      from gi in Teams.GuestInvitation,
        where: gi.id == ^guest_invitation.id
    )

    prune_guest_invitations(site.team)
  end

  def remove_site_transfer(site_transfer) do
    Repo.delete_all(
      from st in Teams.SiteTransfer,
        where: st.id == ^site_transfer.id
    )
  end

  def accept_site_transfer(site_transfer, user) do
    {:ok, _} =
      Repo.transaction(fn ->
        {:ok, team} = Teams.get_or_create(user)
        :ok = transfer_site_ownership(site_transfer.site, team, NaiveDateTime.utc_now(:second))
        Repo.delete_all(from st in Teams.SiteTransfer, where: st.id == ^site_transfer.id)
      end)

    :ok
  end

  def transfer_site(site, user) do
    {:ok, _} =
      Repo.transaction(fn ->
        {:ok, team} = Teams.get_or_create(user)
        :ok = transfer_site_ownership(site, team, NaiveDateTime.utc_now(:second))
      end)

    :ok
  end

  def accept_guest_invitation(guest_invitation, user) do
    guest_invitation = Repo.preload(guest_invitation, :site)

    team_invitation =
      guest_invitation.team_invitation
      |> Repo.preload([
        :team,
        :inviter,
        guest_invitations: :site
      ])

    now = NaiveDateTime.utc_now(:second)

    do_accept(team_invitation, user, now, guest_invitations: [guest_invitation])
  end

  def accept_team_invitation(team_invitation, user) do
    team_invitation = Repo.preload(team_invitation, [:team, :inviter])
    now = NaiveDateTime.utc_now(:second)

    do_accept(team_invitation, user, now, guest_invitations: [])
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
    result =
      Ecto.Multi.new()
      |> Ecto.Multi.put(
        :site_transfer_changeset,
        Teams.SiteTransfer.changeset(site, initiator: initiator, email: invitee_email)
      )
      |> Ecto.Multi.run(:ensure_no_invitations, fn _repo, %{site_transfer_changeset: changeset} ->
        q =
          from ti in Teams.Invitation,
            inner_join: gi in assoc(ti, :guest_invitations),
            where: ti.email == ^invitee_email,
            where: ti.team_id == ^site.team_id,
            where: gi.site_id == ^site.id

        if Repo.exists?(q) do
          {:error, Ecto.Changeset.add_error(changeset, :invitation, "already sent")}
        else
          {:ok, :pass}
        end
      end)
      |> Ecto.Multi.insert(
        :site_transfer,
        fn %{site_transfer_changeset: changeset} -> changeset end,
        on_conflict: [set: [updated_at: now]],
        conflict_target: [:email, :site_id],
        returning: true
      )
      |> Repo.transaction()

    case result do
      {:ok, success} ->
        {:ok, success.site_transfer}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  defp do_accept(team_invitation, user, now, opts) do
    send_email? = Keyword.get(opts, :send_email?, true)
    guest_invitations = Keyword.get(opts, :guest_invitations, team_invitation.guest_invitations)

    Repo.transaction(fn ->
      with {:ok, team_membership} <-
             create_team_membership(team_invitation.team, team_invitation.role, user, now),
           {:ok, guest_memberships} <-
             create_guest_memberships(team_membership, guest_invitations, now) do
        # Clean up guest invitations after accepting
        guest_invitation_ids = Enum.map(guest_invitations, & &1.id)
        Repo.delete_all(from gi in Teams.GuestInvitation, where: gi.id in ^guest_invitation_ids)

        if team_membership.role != :guest do
          Repo.delete_all(from ti in Teams.Invitation, where: ti.id == ^team_invitation.id)
        end

        prune_guest_invitations(team_invitation.team)

        # Prune guest memberships if any exist when team membership role
        # is other than guest
        maybe_prune_guest_memberships(team_membership)

        if send_email? do
          send_invitation_accepted_email(team_invitation, guest_invitations)
        end

        %{team_membership: team_membership, guest_memberships: guest_memberships}
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp maybe_prune_guest_memberships(%Teams.Membership{role: :guest}), do: :ok

  defp maybe_prune_guest_memberships(%Teams.Membership{} = team_membership) do
    team_membership
    |> Ecto.assoc(:guest_memberships)
    |> Repo.delete_all()

    :ok
  end

  defp transfer_site_ownership(site, team, now) do
    site =
      Repo.preload(site, [
        :team,
        :owner,
        guest_memberships: [team_membership: :user],
        guest_invitations: [team_invitation: :inviter]
      ])

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

    {:ok, prior_owner} = Teams.get_owner(prior_team)

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

    on_ee do
      :unlocked = Billing.SiteLocker.update_sites_for(team, send_email?: false)
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

  on_ee do
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
  else
    def ensure_can_take_ownership(_site, _team) do
      :ok
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
  def check_invitation_permissions(%Teams.Team{} = team, inviter, invitation_role, opts) do
    check_permissions? = Keyword.get(opts, :check_permissions, true)

    if check_permissions? do
      case Teams.Memberships.team_role(team, inviter) do
        {:ok, :owner} when invitation_role == :owner ->
          :ok

        {:ok, inviter_role}
        when inviter_role in [:owner, :admin] and invitation_role != :owner ->
          :ok

        _ ->
          {:error, :forbidden}
      end
    else
      :ok
    end
  end

  def check_invitation_permissions(%Plausible.Site{} = site, inviter, invitation_role, opts) do
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
  def ensure_new_membership(_site_or_team, nil, _role), do: :ok

  def ensure_new_membership(_site_or_team, _invitee, :owner), do: :ok

  def ensure_new_membership(%Teams.Team{} = team, invitee, _role) do
    case Teams.Memberships.team_role(team, invitee) do
      {:ok, :guest} -> :ok
      {:error, :not_a_member} -> :ok
      {:ok, _} -> {:error, :already_a_member}
    end
  end

  def ensure_new_membership(%Plausible.Site{} = site, invitee, _role) do
    if Teams.Memberships.site_role(site, invitee) == {:error, :not_a_member} do
      :ok
    else
      {:error, :already_a_member}
    end
  end

  defp create_invitation(site, invitee_email, role, inviter) do
    Repo.transaction(fn ->
      with {:ok, team_invitation} <-
             create_team_invitation(site.team, invitee_email, inviter,
               ensure_no_site_transfers_for: site.id
             ),
           {:ok, guest_invitation} <- create_guest_invitation(team_invitation, site, role) do
        guest_invitation
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp create_team_invitation(team, invitee_email, inviter, opts \\ []) do
    now = NaiveDateTime.utc_now(:second)
    role = Keyword.get(opts, :role, :guest)

    result =
      Ecto.Multi.new()
      |> Ecto.Multi.put(
        :changeset,
        Teams.Invitation.changeset(team, email: invitee_email, role: role, inviter: inviter)
      )
      |> Ecto.Multi.run(:ensure_no_site_transfers, fn _repo, %{changeset: changeset} ->
        ensure_no_site_transfers(changeset, opts[:ensure_no_site_transfers_for], invitee_email)
      end)
      |> Ecto.Multi.insert(
        :team_invitation,
        & &1.changeset,
        on_conflict: [set: [updated_at: now, role: role]],
        conflict_target: [:team_id, :email],
        returning: true
      )
      |> Ecto.Multi.run(:prune_guest_entries, fn _repo, %{team_invitation: team_invitation} ->
        if team_invitation.role != :guest do
          team_invitation
          |> Ecto.assoc(:guest_invitations)
          |> Repo.delete_all()
        end

        {:ok, nil}
      end)
      |> Repo.transaction()

    case result do
      {:ok, success} ->
        {:ok, success.team_invitation}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
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

  def send_invitation_email(%Teams.Invitation{} = team_invitation, invitee) do
    email =
      if invitee do
        PlausibleWeb.Email.existing_user_team_invitation(
          team_invitation.email,
          team_invitation.team,
          team_invitation.inviter
        )
      else
        PlausibleWeb.Email.new_user_team_invitation(
          team_invitation.email,
          team_invitation.invitation_id,
          team_invitation.team,
          team_invitation.inviter
        )
      end

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

  @team_role_type Plausible.Teams.Membership.__schema__(:type, :role)

  defp create_team_membership(team, role, user, now) do
    conflict_query =
      from(tm in Teams.Membership,
        update: [
          set: [
            updated_at: ^now,
            role:
              fragment(
                "CASE WHEN ? = 'guest' THEN ? ELSE ? END",
                tm.role,
                type(^role, ^@team_role_type),
                tm.role
              )
          ]
        ]
      )

    team
    |> Teams.Membership.changeset(user, role)
    |> Repo.insert(
      on_conflict: conflict_query,
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

  defp send_invitation_accepted_email(team_invitation, []) do
    team_invitation.inviter.email
    |> PlausibleWeb.Email.team_invitation_accepted(team_invitation.email, team_invitation.team)
    |> Plausible.Mailer.send()
  end

  defp send_invitation_accepted_email(team_invitation, [guest_invitation | _]) do
    team_invitation.inviter.email
    |> PlausibleWeb.Email.guest_invitation_accepted(team_invitation.email, guest_invitation.site)
    |> Plausible.Mailer.send()
  end

  defp ensure_no_site_transfers(_, nil, _) do
    {:ok, :skip}
  end

  defp ensure_no_site_transfers(changeset, site_id, invitee_email)
       when is_integer(site_id) and is_binary(invitee_email) do
    q =
      from st in Teams.SiteTransfer,
        where: st.email == ^invitee_email,
        where: st.site_id == ^site_id

    if Repo.exists?(q) do
      {:error, Ecto.Changeset.add_error(changeset, :invitation, "already sent")}
    else
      {:ok, :pass}
    end
  end
end
