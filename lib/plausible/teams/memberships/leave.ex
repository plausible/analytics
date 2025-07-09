defmodule Plausible.Teams.Memberships.Leave do
  @moduledoc """
  Service for leaving a team by member.
  """

  alias Plausible.Repo
  alias Plausible.Teams
  alias Plausible.Teams.Memberships

  @spec leave(Teams.Team.t(), Plausible.Auth.User.t(), Keyword.t()) ::
          {:ok, Teams.Membership.t()} | {:error, :only_one_owner | :membership_not_found}
  def leave(team, user, opts \\ []) do
    with {:ok, team_membership} <- Memberships.get_team_membership(team, user.id),
         :ok <- check_owner_can_leave(team, team_membership.role) do
      team_membership = Repo.preload(team_membership, [:team, :user])

      {:ok, _} =
        Repo.transaction(fn ->
          delete_membership!(team_membership)

          Plausible.Segments.after_user_removed_from_team(
            team_membership.team,
            team_membership.user
          )
        end)

      if Keyword.get(opts, :send_email?, true) do
        send_team_member_left_email(team_membership)
      end

      {:ok, team_membership}
    end
  end

  defp delete_membership!(team_membership) do
    user = team_membership.user

    Repo.delete!(team_membership)

    if Plausible.Users.type(user) == :sso do
      {:ok, :deleted} = Plausible.Auth.delete_user(user)
    end

    :ok
  end

  defp check_owner_can_leave(team, :owner) do
    if Memberships.owners_count(team) > 1 do
      :ok
    else
      {:error, :only_one_owner}
    end
  end

  defp check_owner_can_leave(_team, _role), do: :ok

  def send_team_member_left_email(team_membership) do
    team_membership
    |> PlausibleWeb.Email.team_member_left()
    |> Plausible.Mailer.send()
  end
end
