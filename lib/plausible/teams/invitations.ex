defmodule Plausible.Teams.Invitations do
  @moduledoc false

  alias Plausible.Auth
  alias Plausible.Billing
  alias Plausible.Repo
  alias Plausible.Teams

  def invite(site, inviter, invitee_email, role, opts \\ [])

  # ownership transfer => site transfer
  def invite(_site, _inviter, _invitee_email, :owner, _opts) do
    # TODO
    {:error, :not_implemented}
  end

  def invite(site, inviter, invitee_email, role, opts) do
    check_permissions? = opts[:check_permissions]
    site = Repo.preload(site, :team)
    role = translate_role(role)

    with :ok <- check_invitation_permissions(site.team, inviter, check_permissions?),
         :ok <- check_team_member_limit(site.team, role, invitee_email),
         invitee = Auth.find_user_by(email: invitee_email),
         :ok <- ensure_transfer_valid(site.team, invitee, role),
         :ok <- ensure_new_membership(site, invitee, role),
         {:ok, guest_invitation} <- create_invitation(site, invitee_email, role, inviter) do
      send_invitation_email(guest_invitation, invitee)
      {:ok, guest_invitation}
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

  defp check_team_member_limit(_team, :owner, _invitee_email), do: :ok

  defp check_team_member_limit(team, _role, invitee_email) do
    limit = Teams.Billing.team_member_limit(team)
    usage = Teams.Billing.team_member_usage(team, exclude_emails: [invitee_email])

    if Billing.Quota.below_limit?(usage, limit) do
      :ok
    else
      {:error, {:over_limit, limit}}
    end
  end

  defp ensure_transfer_valid(_team, nil, _role), do: :ok

  defp ensure_transfer_valid(_site, _new_owner, :owner), do: {:error, :use_site_transfer}

  defp ensure_transfer_valid(_site, _new_owner, _role), do: :ok

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
end
