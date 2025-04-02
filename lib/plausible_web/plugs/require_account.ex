defmodule PlausibleWeb.RequireAccountPlug do
  alias PlausibleWeb.Router.Helpers, as: Routes
  import Plug.Conn

  @unverified_email_exceptions [
    ["settings", "security", "email", "cancel"],
    ["activate"],
    ["activate", "request-code"],
    ["me"]
  ]

  def init(options) do
    options
  end

  def call(conn, _opts) do
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
end
