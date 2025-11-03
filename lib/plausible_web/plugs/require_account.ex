defmodule PlausibleWeb.RequireAccountPlug do
  alias PlausibleWeb.Router.Helpers, as: Routes
  import Plug.Conn

  @unverified_email_exceptions [
    ["settings", "security", "email", "cancel"],
    ["activate"],
    ["activate", "request-code"],
    ["me"]
  ]

  @force_2fa_exceptions [
    ["2fa", "setup", "force-initiate"],
    ["2fa", "setup", "initiate"],
    ["2fa", "setup", "verify"],
    ["team", "select"]
  ]

  def init(options) do
    options
  end

  def call(conn, _opts) do
    conn
    |> require_verified_user()
    |> maybe_force_2fa()
  end

  defp require_verified_user(conn) do
    user = conn.assigns[:current_user]

    cond do
      is_nil(user) ->
        conn
        |> Phoenix.Controller.redirect(to: redirect_to(conn))
        |> halt

      not user.email_verified and
          conn.path_info not in @unverified_email_exceptions ->
        conn
        |> Phoenix.Controller.redirect(to: "/activate")
        |> halt

      true ->
        conn
    end
  end

  defp maybe_force_2fa(%{halted: true} = conn), do: conn

  defp maybe_force_2fa(conn) do
    user = conn.assigns[:current_user]
    team = conn.assigns[:current_team]

    if must_enable_2fa?(user, team) and conn.path_info not in @force_2fa_exceptions do
      conn
      |> Phoenix.Controller.redirect(to: Routes.auth_path(conn, :force_initiate_2fa_setup))
      |> halt()
    else
      conn
    end
  end

  defp redirect_to(%Plug.Conn{method: "GET"} = conn) do
    return_to =
      if conn.query_string && String.length(conn.query_string) > 0 do
        conn.request_path <> "?" <> conn.query_string
      else
        conn.request_path
      end

    Routes.auth_path(conn, :login_form, return_to: return_to)
  end

  defp redirect_to(conn), do: Routes.auth_path(conn, :login_form)

  defp must_enable_2fa?(user, team) when is_nil(user) or is_nil(team), do: false

  defp must_enable_2fa?(user, team) do
    not Plausible.Auth.TOTP.enabled?(user) and Plausible.Teams.force_2fa_enabled?(team)
  end
end
