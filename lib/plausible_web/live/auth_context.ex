defmodule PlausibleWeb.Live.AuthContext do
  @moduledoc """
  This module supplies LiveViews with currently logged in user data _if_ session
  data contains a valid token.

  Must be kept in sync with `PlausibleWeb.AuthPlug`.
  """

  import Phoenix.Component

  alias Plausible.Teams
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
      |> assign_new(:team_from_session, fn _ ->
        session["current_team_id"]
        |> Teams.get()
        |> Teams.with_subscription()
        |> Plausible.Repo.preload(:owners)
      end)
      |> assign_new(:my_team, fn context ->
        current_team = context.team_from_session

        current_team_owner? =
          case current_team &&
                 Plausible.Teams.Memberships.team_role(current_team, context.current_user) do
            {:ok, :owner} -> true
            _ -> false
          end

        case {current_team_owner?, current_team, context.current_user} do
          {_, nil, nil} -> nil
          {true, %Teams.Team{}, _} -> current_team
          {_, _, %{team_memberships: [%{team: team} | _]}} -> team
          {_, _, %{team_memberships: []}} -> nil
        end
      end)
      |> assign_new(:current_team, fn context ->
        context.team_from_session || context.my_team
      end)

    {:cont, socket}
  end
end
