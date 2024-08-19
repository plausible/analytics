defmodule PlausibleWeb.SuperAdminOnlyPlug do
  @moduledoc false

  import Plug.Conn
  use Plausible.Repo

  def init(options) do
    options
  end

  def call(conn, _opts) do
    case PlausibleWeb.UserAuth.get_user(conn) do
      {:ok, user} ->
        if Plausible.Auth.is_super_admin?(user.id) do
          assign(conn, :current_user, user)
        else
          conn |> send_resp(403, "Not allowed") |> halt
        end

      {:error, _} ->
        conn |> send_resp(403, "Not allowed") |> halt
    end
  end
end
