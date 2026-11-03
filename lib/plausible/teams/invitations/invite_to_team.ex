defmodule Plausible.Teams.Invitations.InviteToTeam do
  @moduledoc """
  Service for inviting new or existing users to team.
  """

  alias Plausible.Repo
  alias Plausible.Teams

  @type invite_entry() :: %{email: String.t(), role: atom() | String.t()}

  @doc """
  Creates team invitations for all given entries in a single transaction.
  Either all of them get created, or none. Does not send any emails yet.

  Returns `{:error, :invalid_email}` or `{:error, :duplicate_emails}`
  without touching the database if any of the entries' emails is invalid,
  or if the same email appears more than once.
  """
  @spec invite_all(
          Teams.Team.t(),
          Plausible.Auth.User.t(),
          [invite_entry()]
        ) ::
          {:ok, [Teams.Invitation.t()]} | {:error, any()}
  def invite_all(team, inviter, entries) do
    with :ok <- validate_emails(Enum.map(entries, & &1.email)) do
      do_invite_all(Repo.preload(team, [:owners]), inviter, entries)
    end
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

  defp do_invite_all(team, inviter, entries) do
    Repo.transact(fn ->
      Enum.reduce_while(entries, {:ok, []}, fn entry, {:ok, invitations} ->
        case do_invite(team, inviter, entry.email, entry.role) do
          {:ok, invitation} -> {:cont, {:ok, invitations ++ [invitation]}}
          {:error, _} = error -> {:halt, error}
        end
      end)
    end)
  end

  defp validate_emails(emails) do
    cond do
      not Enum.all?(emails, &valid_email?/1) -> {:error, :invalid_email}
      # emails are case-insensitive in the database (citext)
      Enum.uniq_by(emails, &String.downcase/1) != emails -> {:error, :duplicate_emails}
      true -> :ok
    end
  end

  defp valid_email?(email) do
    String.contains?(email, "@") and String.contains?(email, ".")
  end

  defp do_invite(team, inviter, invitee_email, role) do
    with :ok <-
           Teams.TeamRolePermissions.ensure_can_invite(team, inviter, role),
         :ok <- Teams.Invitations.check_team_member_limit(team, role, invitee_email),
         invitee = Plausible.Auth.find_user_by(email: invitee_email),
         :ok <- Teams.Invitations.ensure_new_membership(team, invitee, role),
         :ok <- Teams.Invitations.ensure_no_invitations(team, invitee_email) do
      Teams.Invitations.invite(team, invitee_email, role, inviter)
    end
  end
end
