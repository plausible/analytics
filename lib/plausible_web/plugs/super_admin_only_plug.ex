defmodule PlausibleWeb.SuperAdminOnlyPlug do
  @moduledoc false

  use Plausible.Repo

  import Plug.Conn

  alias PlausibleWeb.Router.Helpers, as: Routes

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
      |> Phoenix.Controller.redirect(to: Routes.auth_path(conn, :login_form))
      |> halt()
    end
  end
end
