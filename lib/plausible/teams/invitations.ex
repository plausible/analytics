defmodule Plausible.Teams.Invitations do
  @moduledoc false

  alias Plausible.Auth
  alias Plausible.Billing
  alias Plausible.Repo
  alias Plausible.Teams

  def invite(site, inviter, invitee_email, role, opts \\ [])

  def invite(site, initiator, invitee_email, :owner, opts) do
    check_permissions? = opts[:check_permissions]
    site = Repo.preload(site, :team)

    with :ok <- check_transfer_permissions(site.team, initiator, check_permissions?),
         new_owner = Plausible.Auth.find_user_by(email: invitee_email),
         :ok <- ensure_transfer_valid(site.team, new_owner),
         {:ok, site_transfer} <- create_site_transfer(site, initiator, invitee_email) do
      send_transfer_init_email(site_transfer, new_owner)
      {:ok, site_transfer}
    end
  end

  def invite(site, inviter, invitee_email, role, opts) do
    check_permissions? = opts[:check_permissions]
    site = Repo.preload(site, :team)
    role = translate_role(role)

    with :ok <- check_invitation_permissions(site.team, inviter, check_permissions?),
         :ok <- check_team_member_limit(site.team, role, invitee_email),
         invitee = Auth.find_user_by(email: invitee_email),
         :ok <- ensure_new_membership(site, invitee, role),
         {:ok, guest_invitation} <- create_invitation(site, invitee_email, role, inviter) do
      send_invitation_email(guest_invitation, invitee)
      {:ok, guest_invitation}
    end
  end

  def accept(invitation_id, user) do
    with {:ok, team_invitation} <- find_for_user(invitation_id, user) do
      if team_invitation.role == :owner do
        # TODO: site transfer
        {:error, :not_implemented}
      else
        do_accept(team_invitation, user)
      end
    end
  end

  defp check_transfer_permissions(_team, _initiator, false = _check_permissions?) do
    :ok
  end

  defp check_transfer_permissions(team, initiator, _) do
    case Teams.Memberships.team_role(team, initiator) do
      {:ok, :owner} -> :ok
      _ -> {:error, :forbidden}
    end
  end

  defp ensure_transfer_valid(_team, nil), do: :ok

  defp ensure_transfer_valid(team, new_owner) do
    case Teams.Memberships.team_role(team, new_owner) do
      {:ok, :owner} -> {:error, :transfer_to_self}
      _ -> :ok
    end
  end

  defp create_site_transfer(site, initiator, invitee_email) do
    site
    |> Teams.SiteTransfer.changeset(initiator: initiator, email: invitee_email)
    |> Repo.insert()
  end

  defp send_transfer_init_email(site_transfer, new_owner) do
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

  defp do_accept(team_invitation, user) do
    guest_invitations = team_invitation.guest_invitations

    Repo.transaction(fn ->
      with {:ok, team_membership} <- create_team_membership(team_invitation, user),
           {:ok, _guest_memberships} <-
             create_guest_memberships(team_membership, guest_invitations) do
        Repo.delete!(team_invitation)
        send_invitation_accepted_email(team_invitation, guest_invitations)

        team_membership
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp find_for_user(invitation_id, user) do
    invitation =
      Teams.Invitation
      |> Repo.get_by(invitation_id: invitation_id, email: user.email)
      |> Repo.preload([:team, :inviter, guest_invitations: :site])

    if invitation do
      {:ok, invitation}
    else
      {:error, :invitation_not_found}
    end
  end

  defp check_invitation_permissions(_team, _inviter, false = _check_permission?) do
    :ok
  end

  defp check_invitation_permissions(team, inviter, _) do
    case Teams.Memberships.team_role(team, inviter) do
      {:ok, role} when role in [:owner, :admin] -> :ok
      _ -> {:error, :forbidden}
    end
  end

  defp translate_role(:admin), do: :editor
  defp translate_role(role), do: role

  defp check_team_member_limit(team, _role, invitee_email) do
    limit = Teams.Billing.team_member_limit(team)
    usage = Teams.Billing.team_member_usage(team, exclude_emails: [invitee_email])

    if Billing.Quota.below_limit?(usage, limit) do
      :ok
    else
      {:error, {:over_limit, limit}}
    end
  end

  defp ensure_new_membership(_site, nil, _role), do: :ok

  defp ensure_new_membership(site, invitee, _role) do
    if is_nil(Teams.Memberships.site_role(site, invitee)) do
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
    |> Repo.insert(on_conflict: [set: [updated_at: now]], conflict_target: [:team_id, :email])
  end

  defp create_guest_invitation(team_invitation, site, role) do
    team_invitation
    |> Teams.GuestInvitation.changeset(site, role)
    |> Repo.insert()
  end

  defp send_invitation_email(guest_invitation, invitee) do
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
          team_invitation.invitation_id,
          guest_invitation.site,
          team_invitation.inviter
        )
      end

    Plausible.Mailer.send(email)
  end

  defp create_team_membership(team_invitation, user) do
    now = NaiveDateTime.utc_now(:second)
    %{team: team, role: role} = team_invitation

    team
    |> Teams.Membership.changeset(user, role)
    |> Repo.insert(
      on_conflict: [set: [updated_at: now]],
      conflict_target: [:team_id, :user_id]
    )
  end

  defp create_guest_memberships(_team_membership, []) do
    {:ok, []}
  end

  defp create_guest_memberships(%{role: role} = _team_membership, _) when role != :guest do
    {:ok, []}
  end

  defp create_guest_memberships(team_membership, guest_invitations) do
    now = NaiveDateTime.utc_now(:second)

    Enum.reduce_while(guest_invitations, {:ok, []}, fn guest_invitation,
                                                       {:ok, guest_memberships} ->
      result =
        team_membership
        |> Teams.GuestMembership.changeset(guest_invitation.site, guest_invitation.role)
        |> Repo.insert(
          on_conflict: [set: [updated_at: now, role: guest_invitation.role]],
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
