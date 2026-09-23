defmodule Plausible.Teams.Invitations.InviteToTeam do
  @moduledoc """
  Service for inviting new or existing users to team.
  """

  alias Plausible.Repo
  alias Plausible.Teams

  @valid_roles Plausible.Teams.Invitation.roles() -- [:guest]
  @valid_roles @valid_roles ++ Enum.map(@valid_roles, &to_string/1)

  @type invite_entry() :: %{email: String.t(), role: atom() | String.t()}

  # DEPRECATED: to be removed together with `Teams.Management.Layout.persist/2`,
  # its only caller outside tests. Use `invite_all/4` + `send_invitation_emails/1`
  # instead. `invite_all/4` duplicates this function's body on purpose, so that
  # this one can be deleted as-is once nothing calls it anymore.
  def invite(team, inviter, invitee_email, role, opts \\ [])

  def invite(team, inviter, invitee_email, role, opts) when role in @valid_roles do
    with team <- Repo.preload(team, [:owners]),
         :ok <- Teams.Invitations.check_invitation_permissions(team, inviter, role, opts),
         :ok <- Teams.Invitations.check_team_member_limit(team, role, invitee_email),
         invitee = Plausible.Auth.find_user_by(email: invitee_email),
         :ok <- Teams.Invitations.ensure_new_membership(team, invitee, role),
         {:ok, invitation} <- Teams.Invitations.invite(team, invitee_email, role, inviter) do
      if Keyword.get(opts, :send_email?, true) do
        send_invitation_email(invitation, invitee)
      end

      {:ok, invitation}
    end
  end

  def invite(_team, _inviter, _invitee_email, role, _opts) do
    raise "Invalid role passed: #{inspect(role)}"
  end

  @doc """
  Creates team invitations for all given entries in a single transaction.
  Either all of them get created, or none. Does not send any emails yet.
  """
  @spec invite_all(
          Teams.Team.t(),
          Plausible.Auth.User.t(),
          [invite_entry()],
          Keyword.t()
        ) ::
          {:ok, [Teams.Invitation.t()]} | {:error, any()}
  def invite_all(team, inviter, entries, opts \\ []) do
    team = Repo.preload(team, [:owners])

    Repo.transaction(fn ->
      Enum.map(entries, fn %{email: email, role: role} ->
        case do_invite(team, inviter, email, role, opts) do
          {:ok, invitation} -> invitation
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
    end)
  end

  @spec send_invitation_emails([Teams.Invitation.t()]) :: :ok
  def send_invitation_emails(invitations) do
    Enum.each(invitations, fn invitation ->
      invitee = Plausible.Auth.find_user_by(email: invitation.email)
      send_invitation_email(invitation, invitee)
    end)
  end

  def send_invitation_email(invitation, invitee) do
    invitation
    |> Repo.preload([:team, :inviter])
    |> Teams.Invitations.send_invitation_email(invitee)
  end

  defp do_invite(team, inviter, invitee_email, role, opts) when role in @valid_roles do
    with :ok <- Teams.Invitations.check_invitation_permissions(team, inviter, role, opts),
         :ok <- Teams.Invitations.check_team_member_limit(team, role, invitee_email),
         invitee = Plausible.Auth.find_user_by(email: invitee_email),
         :ok <- Teams.Invitations.ensure_new_membership(team, invitee, role) do
      Teams.Invitations.invite(team, invitee_email, role, inviter)
    end
  end

  defp do_invite(_team, _inviter, _invitee_email, role, _opts) do
    raise "Invalid role passed: #{inspect(role)}"
  end
end
