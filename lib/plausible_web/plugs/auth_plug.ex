defmodule PlausibleWeb.AuthPlug do
  @moduledoc """
  Plug for populating conn assigns with user data
  on the basis of authenticated session token.

  Must be kept in sync with `PlausibleWeb.Live.AuthContext`.
  """

  import Plug.Conn
  use Plausible.Repo

  alias Plausible.Teams
  alias PlausibleWeb.UserAuth

  def init(options) do
    options
  end

  def call(conn, _opts) do
    case UserAuth.get_user_session(conn) do
      {:ok, user_session} ->
        user = user_session.user

        current_team =
          conn
          |> Plug.Conn.get_session("current_team_id")
          |> Plausible.Teams.get()
          |> Teams.with_subscription()
          |> Repo.preload(:owners)

        current_team_owner? =
          case current_team && Teams.Memberships.team_role(current_team, user) do
            {:ok, :owner} -> true
            _ -> false
          end

        my_team =
          case {current_team_owner?, current_team, user} do
            {true, %Teams.Team{}, _} -> current_team
            {_, _, %{team_memberships: [%{team: team} | _]}} -> team
            {_, _, %{team_memberships: []}} -> nil
          end

        Plausible.OpenTelemetry.add_user_attributes(user)
        Sentry.Context.set_user_context(%{id: user.id, name: user.name, email: user.email})

        conn
        |> assign(:current_user, user)
        |> assign(:current_user_session, user_session)
        |> assign(:my_team, my_team)
        |> assign(:current_team, current_team || my_team)
        |> assign(:multiple_teams?, Teams.Users.teams_count(user) > 1)

      _ ->
        conn
    end
  end
end
