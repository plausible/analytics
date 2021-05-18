defmodule PlausibleWeb.RequireAccountPlug do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _opts) do
    user = conn.assigns[:current_user]

    cond do
      is_nil(user) ->
        Plug.Conn.put_session(conn, :login_dest, conn.request_path)
        |> Phoenix.Controller.redirect(to: "/login")
        |> halt

      not user.email_verified and conn.path_info not in [["activate"], ["me"]] ->
        conn
        |> Phoenix.Controller.redirect(to: "/activate")
        |> halt

      true ->
        conn
    end
  end
end
