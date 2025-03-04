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

        %{current_user: user} = context ->
          current_team = context.team_from_session

          current_team_owner? =
            (current_team || %{})
            |> Map.get(:owners, [])
            |> Enum.any?(&(&1.id == user.id))

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
      end)
      |> assign_new(:current_team, fn context ->
        context.team_from_session || context.my_team
      end)
      |> assign_new(:teams_count, fn
        %{current_user: nil} -> 0
        %{current_user: user} -> length(user.team_memberships)
      end)
      |> assign_new(:multiple_teams?, fn context ->
        context.teams_count > 1
      end)

    {:cont, socket}
  end
end
