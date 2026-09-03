defmodule PlausibleWeb.Plugs.MaybeDisableRegistration do
  @moduledoc """
  Plug toggling registration according to selfhosted state.

  LiveView events don't go through the router pipeline, so
  `PlausibleWeb.Live.RegisterForm` re-checks registration state with the
  predicates below. Which predicate applies is decided by whether a valid
  invitation is present, not by route — an invalid or expired invitation must
  be treated as public registration.
  """

  import Phoenix.Controller
  import Plug.Conn

  alias Plausible.Release
  alias PlausibleWeb.Router.Helpers, as: Routes

  @disabled_message "Registration is disabled on this instance"

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    if disabled?(conn.assigns.disable_registration_for) do
      conn
      |> put_flash(:error, @disabled_message)
      |> redirect(to: Routes.auth_path(conn, :login_form))
      |> halt()
    else
      conn
    end
  end

  def disabled_message, do: @disabled_message

  def public_registration_disabled? do
    disabled?([:invite_only, true])
  end

  def invited_registration_disabled? do
    disabled?(true)
  end

  defp disabled?(disabled_for) do
    selfhost_config = Application.get_env(:plausible, :selfhost)
    disable_registration = Keyword.fetch!(selfhost_config, :disable_registration)

    disable_registration in List.wrap(disabled_for) and not Release.should_be_first_launch?()
  end
end
