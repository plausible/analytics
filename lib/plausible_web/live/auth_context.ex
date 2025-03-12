defmodule PlausibleWeb.Live.AuthContext do
  @moduledoc """
  This module supplies LiveViews with currently logged in user data _if_ session
  data contains a valid token.

  Must be kept in sync with `PlausibleWeb.AuthPlug`.
  """

  import Phoenix.Component

  alias PlausibleWeb.UserAuth

  defmacro __using__(_) do
    quote do
      on_mount unquote(__MODULE__)
    end
  end

  def on_mount(:default, _params, session, socket) do
    socket =
      socket
      |> assign_new(:current_user_session, fn ->
        case UserAuth.get_user_session(session) do
          {:ok, user_session} -> user_session
          _ -> nil
        end
      end)
      |> assign_new(:current_user, fn context ->
        case context.current_user_session do
          %{user: user} -> user
          _ -> nil
        end
      end)
      |> assign_new(:team_from_session, fn
        %{current_user: nil} ->
          nil

        %{current_user: user} ->
          if current_team_id = session["current_team_id"] do
            user.team_memberships
            |> Enum.find(%{}, &(&1.team.identifier == current_team_id))
            |> Map.get(:team)
          end
      end)
      |> assign_new(:my_team, fn
        %{current_user: nil} ->
          nil

        %{current_user: user} ->
          user.team_memberships
          |> Enum.find(%{}, &(&1.role == :owner and &1.team.setup_complete == false))
          |> Map.get(:team)
      end)
      |> assign_new(:current_team, fn
        %{current_user: nil} ->
          nil

        %{team_from_session: %{} = team_from_session} ->
          team_from_session

        %{my_team: %{} = my_team} ->
          my_team

        _ ->
          nil
      end)
      |> assign_new(
        :current_team_role,
        fn
          %{current_user: user = %{}, current_team: current_team = %{}} ->
            Enum.find_value(user.team_memberships, fn team_membership ->
              if team_membership.team_id == current_team.id do
                team_membership.role
              end
            end)

          %{my_team: %{}} ->
            :owner

          _ ->
            nil
        end
      )
      |> assign_new(:teams, fn
        %{current_user: nil} ->
          []

        %{current_user: user} ->
          user.team_memberships
          |> Enum.sort_by(fn tm -> [tm.role != :owner, tm.team_id] end)
          |> Enum.map(&Map.fetch!(&1, :team))
          |> Enum.take(3)
      end)
      |> assign_new(:teams_count, fn
        %{current_user: nil} -> 0
        %{current_user: user} -> length(user.team_memberships)
      end)
      |> assign_new(:more_teams?, fn context ->
        context.teams_count > 3
      end)

    {:cont, socket}
  end
end
