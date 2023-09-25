defmodule PlausibleWeb.Plugs.MaybeDisableRegistration do
  @moduledoc """
  Plug toggling registration according to selfhosted state.
  """

  import Phoenix.Controller
  import Plug.Conn

  alias Plausible.Release
  alias PlausibleWeb.Router.Helpers, as: Routes

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    disabled_for = List.wrap(conn.assigns.disable_registration_for)

    selfhost_config = Application.get_env(:plausible, :selfhost)
    disable_registration = Keyword.fetch!(selfhost_config, :disable_registration)
    first_launch? = Release.should_be_first_launch?()

    cond do
      first_launch? ->
        conn

      disable_registration in disabled_for ->
        conn
        |> put_flash(:error, "Registration is disabled on this instance")
        |> redirect(to: Routes.auth_path(conn, :login_form))
        |> halt()

      true ->
        conn
    end
  end
end
