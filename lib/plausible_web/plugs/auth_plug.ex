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

        current_team_id_from_session = Plug.Conn.get_session(conn, "current_team_id")
        current_team_id = conn.params["__team"] || current_team_id_from_session

        {current_team, current_team_role} =
          if current_team_id do
            team_membership =
              Enum.find(user.team_memberships, %{}, &(&1.team.identifier == current_team_id))

            {Map.get(team_membership, :team), Map.get(team_membership, :role)}
          else
            {nil, nil}
          end

        conn =
          cond do
            current_team && current_team_id != current_team_id_from_session ->
              Plug.Conn.put_session(conn, "current_team_id", current_team_id)

            is_nil(current_team) && not is_nil(current_team_id_from_session) ->
              Plug.Conn.delete_session(conn, "current_team_id")

            true ->
              conn
          end

        my_team =
          user.team_memberships
          |> Enum.find(%{}, &(&1.role == :owner and &1.team.setup_complete == false))
          |> Map.get(:team)

        teams_count = length(user.team_memberships)

        teams =
          user.team_memberships
          |> Enum.filter(& &1.team.setup_complete)
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
        |> assign(:current_team_role, current_team_role || (my_team && :owner))
        |> assign(:teams_count, teams_count)
        |> assign(:teams, teams)
        |> assign(:more_teams?, teams_count > 3)

      _ ->
        conn
    end
  end
end
