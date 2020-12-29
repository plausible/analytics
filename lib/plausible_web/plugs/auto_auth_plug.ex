defmodule PlausibleWeb.AutoAuthPlug do
  import Plug.Conn
  alias PlausibleWeb.AuthController

  def init(options) do
    options
  end

  def call(conn, _opts) do
    cond do
      Keyword.fetch!(Application.get_env(:plausible, :selfhost), :disable_authentication) ->
        conn
        |> AuthController.login(%{
          "email" => Application.fetch_env!(:plausible, :admin_email),
          "password" => Application.fetch_env!(:plausible, :admin_pwd)
        })
        |> halt

      true ->
        Plug.Conn.put_session(conn, :login_dest, conn.request_path)
        |> Phoenix.Controller.redirect(to: "/login")
        |> halt
    end
  end
end
