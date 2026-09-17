defmodule Plausible.Plugs.HandleExpiredSession do
  @moduledoc """
  Plug for handling expired session. Must be added after `AuthPlug`.
  """

  use Plausible

  import Plug.Conn

  alias PlausibleWeb.Router.Helpers, as: Routes

  def init(_) do
    []
  end

  def call(conn, []) do
    maybe_trigger_login(conn, conn.assigns[:expired_session])
  end

  defp maybe_trigger_login(conn, nil), do: conn

  defp maybe_trigger_login(conn, user_session) do
    if Plausible.Users.type(user_session.user) == :sso do
      Plausible.Auth.UserSessions.revoke_by_id(user_session.user, user_session.id)
      trigger_sso_login(conn, user_session.user.email)
    else
      conn
    end
  end

  defp trigger_sso_login(%{method: "GET"} = conn, email) do
    return_to =
      if conn.query_string && String.length(conn.query_string) > 0 do
        conn.request_path <> "?" <> conn.query_string
      else
        conn.request_path
      end

    conn
    |> Phoenix.Controller.redirect(
      to:
        Routes.sso_path(conn, :login_form,
          prefer: "manual",
          email: email,
          autosubmit: true,
          return_to: return_to
        )
    )
    |> halt()
  end

  defp trigger_sso_login(conn, email) do
    conn
    |> Phoenix.Controller.redirect(
      to:
        Routes.sso_path(conn, :login_form,
          prefer: "manual",
          email: email,
          autosubmit: true
        )
    )
    |> halt()
  end
end
