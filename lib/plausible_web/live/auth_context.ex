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
      |> assign_new(:current_team, fn context ->
        case context.current_user do
          nil -> nil
          %{team_memberships: [%{team: team}]} -> team
          %{team_memberships: []} -> nil
        end
      end)

    {:cont, socket}
  end
end
