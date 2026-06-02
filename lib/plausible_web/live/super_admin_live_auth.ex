defmodule PlausibleWeb.Live.SuperAdminLiveAuth do
  @moduledoc """
  LiveView `on_mount` hook that enforces super-admin access on every WebSocket
  mount and reconnect.
  """

  import Phoenix.LiveView, only: [redirect: 2]

  alias PlausibleWeb.UserAuth

  def on_mount(:default, _params, session, socket) do
    current_user =
      case UserAuth.get_user_session(session) do
        {:ok, %{user: user}} -> user
        _ -> nil
      end

    if Plausible.Auth.super_admin?(current_user) do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: "/")}
    end
  end
end
