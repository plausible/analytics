defmodule PlausibleWeb.SuperAdminOnlyPlug do
  @moduledoc false

  import Plug.Conn
  use Plausible.Repo

  def init(options) do
    options
  end

  def call(conn, _opts) do
    with {:ok, user} <- PlausibleWeb.UserAuth.get_user(conn),
         true <- Plausible.Auth.is_super_admin?(user) do
      assign(conn, :current_user, user)
    else
      _ ->
        conn |> send_resp(403, "Not allowed") |> halt
    end
  end
end
