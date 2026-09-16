defmodule PlausibleWeb.Plugs.MaybeDisableRegistration do
  @moduledoc """
  Plug toggling registration according to selfhosted state.
  """

  import Phoenix.Controller
  import Plug.Conn

  alias PlausibleWeb.Router.Helpers, as: Routes

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    case Plausible.Auth.check_registration_enabled(conn.assigns.registration_context) do
      :ok ->
        conn

      {:error, _, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: Routes.auth_path(conn, :login_form))
        |> halt()
    end
  end
end
