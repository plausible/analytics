defmodule PlausibleWeb.AuthPlug do
  @moduledoc """
  Plug for populating conn assigns with user data
  on the basis of authenticated session token.

  Must be kept in sync with `PlausibleWeb.Live.AuthContext`.
  """

  import Plug.Conn

  alias PlausibleWeb.UserAuth

  def init(options) do
    options
  end

  def call(conn, _opts) do
    case UserAuth.get_user_session(conn) do
      {:ok, user_session} ->
        user = user_session.user

        current_team_id = Plug.Conn.get_session(conn, "current_team_id")

        current_team =
          if current_team_id do
            user.team_memberships
            |> Enum.find(%{}, &(&1.team_id == current_team_id))
            |> Map.get(:team)
          end

        current_team_owner? =
          (current_team || %{})
          |> Map.get(:owners, [])
          |> Enum.any?(&(&1.id == user.id))

        my_team =
          if current_team_owner? do
            current_team
          else
            user.team_memberships
            # NOTE: my_team should eventually only hold user's personal team. This requires
            # additional adjustments, which will be done in follow-up work.
            # |> Enum.find(%{}, &(&1.role == :owner and &1.team.setup_complete == false))
            |> List.first(%{})
            |> Map.get(:team)
          end

        teams_count = length(user.team_memberships)

        teams =
          user.team_memberships
          |> Enum.sort_by(fn tm -> [tm.role != :owner, tm.team_id] end)
          |> Enum.map(&Map.fetch!(&1, :team))
          |> Enum.take(3)

        Plausible.OpenTelemetry.add_user_attributes(user)
        Sentry.Context.set_user_context(%{id: user.id, name: user.name, email: user.email})

        conn
        |> assign(:current_user, user)
        |> assign(:current_user_session, user_session)
        |> assign(:my_team, my_team)
        |> assign(:current_team, current_team || my_team)
        |> assign(:teams_count, teams_count)
        |> assign(:teams, teams)
        |> assign(:multiple_teams?, teams_count > 1)

      _ ->
        conn
    end
  end
end
