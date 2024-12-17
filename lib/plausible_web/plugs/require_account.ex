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
        |> Phoenix.Controller.redirect(
          to: Routes.auth_path(conn, :login_form, return_to: conn.request_path)
        )
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
end
