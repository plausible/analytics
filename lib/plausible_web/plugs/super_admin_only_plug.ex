defmodule PlausibleWeb.SuperAdminOnlyPlug do
  @moduledoc false

  use Plausible.Repo

  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _opts) do
    current_user = conn.assigns[:current_user]

    if current_user && Plausible.Auth.is_super_admin?(current_user) do
      conn
    else
      conn
      |> PlausibleWeb.UserAuth.log_out_user()
      |> send_resp(403, "Not allowed")
      |> halt()
    end
  end
end
