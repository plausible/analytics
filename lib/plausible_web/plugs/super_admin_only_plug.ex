defmodule PlausibleWeb.SuperAdminOnlyPlug do
  import Plug.Conn
  use Plausible.Repo

  def init(options) do
    options
  end

  def call(conn, _opts) do
    case get_session(conn, :current_user_id) do
      nil ->
        conn |> send_resp(403, "Not allowed") |> halt

      id ->
        user = Repo.get_by(Plausible.Auth.User, id: id)

        if user && Plausible.Auth.is_super_admin?(user.id) do
          assign(conn, :current_user, user)
        else
          conn |> send_resp(403, "Not allowed") |> halt
        end
    end
  end
end
