defmodule PlausibleWeb.Plugs.MaybeDisableRegistration do
  @moduledoc """
  Plug toggling registration according to selfhosted state.
  """

  use PlausibleWeb.VerifiedRoutes

  import Phoenix.Controller
  import Plug.Conn

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
        |> redirect(to: ~p"/login")
        |> halt()
    end
  end
end
