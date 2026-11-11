defmodule Plausible.Teams.Invitations do
  @moduledoc false

  use Plausible

  import Ecto.Query

  alias Plausible.Auth
  alias Plausible.Billing
  alias Plausible.Repo
  alias Plausible.Teams

  def get_team_invitation(team, invitation_id) do
    invitation = Repo.get_by(Teams.Invitation, team_id: team.id, invitation_id: invitation_id)

    if invitation do
      {:ok, invitation}
    else
      {:error, :invitation_not_found}
    end
  end

  @spec find_by_team_identifier(String.t() | nil, Plausible.Auth.User.t()) ::
          {:ok, Teams.Invitation.t()} | {:error, :invitation_not_found}
  def find_by_team_identifier(nil, _user), do: {:error, :invitation_not_found}

  def find_by_team_identifier(team_identifier, user) do
    invitation_query =
      from ti in Teams.Invitation,
        inner_join: inviter in assoc(ti, :inviter),
        inner_join: team in assoc(ti, :team),
        where: ti.email == ^user.email,
        where: team.identifier == ^team_identifier,
        where: ti.role != :guest,
        preload: [inviter: inviter, team: team]

    case Repo.one(invitation_query) do
      nil ->
        {:error, :invitation_not_found}

      invitation ->
        {:ok, invitation}
    end
  end

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

  @spec pending_team_invitations_for(Auth.User.t() | Teams.Team.t()) :: [Teams.Invitation.t()]
  def pending_team_invitations_for(%Teams.Team{} = team) do
    Repo.all(
      from ti in Teams.Invitation,
        inner_join: inviter in assoc(ti, :inviter),
        where: ti.team_id == ^team.id,
        preload: [inviter: inviter]
    )
  end

  def pending_team_invitations_for(%Plausible.Auth.User{} = user) do
    Repo.all(
      from ti in Teams.Invitation,
        inner_join: inviter in assoc(ti, :inviter),
        inner_join: team in assoc(ti, :team),
        where: ti.email == ^user.email,
        where: ti.role != :guest,
        preload: [inviter: inviter, team: team]
    )
  end

  @spec pending_guest_invitations_for(Auth.User.t()) :: [Teams.GuestInvitation.t()]
  def pending_guest_invitations_for(%Plausible.Auth.User{} = user) do
    Repo.all(
      from gi in Teams.GuestInvitation,
        inner_join: ti in assoc(gi, :team_invitation),
        as: :team_invitation,
        inner_join: inviter in assoc(ti, :inviter),
        inner_join: s in assoc(gi, :site),
        as: :site,
        where: ti.email == ^user.email,
        where:
          not exists(
            from tm in Teams.Membership,
              inner_join: u in assoc(tm, :user),
              left_join: gm in assoc(tm, :guest_memberships),
              on: gm.site_id == parent_as(:site).id,
              where: tm.team_id == parent_as(:team_invitation).team_id,
              where: u.email == ^user.email,
              where: not is_nil(gm.id) or tm.role != :guest,
              select: 1
          ),
        preload: [site: s, team_invitation: {ti, inviter: inviter}]
    )
  end

  @spec pending_site_transfers_for(Auth.User.t()) :: [Teams.SiteTransfer.t()]
  def pending_site_transfers_for(%Plausible.Auth.User{} = user) do
    Repo.all(
      from st in Teams.SiteTransfer,
        inner_join: s in assoc(st, :site),
        inner_join: initiator in assoc(st, :initiator),
        where: st.email == ^user.email,
        preload: [site: s, initiator: initiator]
    )
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
        inner_join: t in assoc(ti, :team),
        inner_join: inviter in assoc(ti, :inviter),
        where: gi.invitation_id == ^guest_invitation_id,
        where: ti.email == ^user.email,
        preload: [site: s, team_invitation: {ti, team: t, inviter: inviter}]

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
      |> Repo.preload([:initiator, site: :team])

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
    site = Repo.preload(site, :team)

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

    if Plausible.Users.type(user) == :sso do
      {:error, :permission_denied}
    else
      do_accept(team_invitation, user, now, guest_invitations: [])
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

        %{
          team: team_invitation.team,
          team_membership: team_membership,
          guest_memberships: guest_memberships
        }
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

  def ensure_new_membership(%Teams.Team{} = team, invitee, _role) do
    case Teams.Memberships.team_role(team, invitee) do
      {:ok, :guest} -> {:error, :already_a_guest}
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

  def ensure_no_invitations(%Teams.Team{} = team, invitee_email) do
    pending_invitation_role =
      Repo.one(
        from ti in Teams.Invitation,
          where: ti.team_id == ^team.id,
          where: ti.email == ^invitee_email,
          select: ti.role
      )

    case pending_invitation_role do
      nil -> :ok
      :guest -> {:error, :invited_as_guest}
      _ -> {:error, :invited_as_member}
    end
  end

  @doc false
  def create_team_invitation(team, invitee_email, inviter, opts \\ []) do
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

  @doc false
  def create_guest_invitation(team_invitation, site, role) do
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

  def create_team_membership(team, role, user, now) do
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
    |> PlausibleWeb.Email.guest_invitation_accepted(
      team_invitation.email,
      team_invitation.team,
      guest_invitation.site
    )
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
