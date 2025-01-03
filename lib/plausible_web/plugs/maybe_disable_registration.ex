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
    cond do
      Release.should_be_first_launch?() ->
        conn

      disable_registration?() ->
        conn
        |> put_flash(:error, "Registration is disabled on this instance")
        |> redirect(to: Routes.auth_path(conn, :login_form))
        |> halt()

      true ->
        conn
    end
  end

  defp disable_registration? do
    if Plausible.ce?() do
      config = Application.get_env(:plausible, :selfhost)
      disable_registration = Keyword.fetch!(config, :disable_registration)
      disable_registration in [:invite_only, true]
    end
  end
end
