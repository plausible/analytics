defmodule PlausibleWeb.Live.RegistrationContext do
  @moduledoc """
  Live context toggling registration according to selfhosted state.
  """

  import Phoenix.LiveView

  alias PlausibleWeb.Router.Helpers, as: Routes

  def on_mount(context, _params, _session, socket) do
    case Plausible.Auth.check_registration_enabled(context) do
      :ok ->
        {:cont, socket}

      {:error, _, message} ->
        socket =
          socket
          |> put_flash(:error, message)
          |> redirect(to: Routes.auth_path(socket, :login_form))

        {:halt, socket}
    end
  end
end
