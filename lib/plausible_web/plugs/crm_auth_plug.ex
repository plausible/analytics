defmodule PlausibleWeb.CRMAuthPlug do
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

        if user && user.id in admin_user_ids() do
          assign(conn, :current_user, user)
        else
          conn |> send_resp(403, "Not allowed") |> halt
        end
    end
  end

  defp admin_user_ids(), do: Application.get_env(:plausible, :admin_user_ids)
end
