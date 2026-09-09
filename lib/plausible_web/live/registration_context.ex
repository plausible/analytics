defmodule PlausibleWeb.Live.RegistrationContext do
  @moduledoc """
  Live context toggling registration according to selfhosted state.
  """

  use PlausibleWeb.VerifiedRoutes

  import Phoenix.LiveView

  def on_mount(context, _params, _session, socket) do
    case Plausible.Auth.check_registration_enabled(context) do
      :ok ->
        {:cont, socket}

      {:error, _, message} ->
        socket =
          socket
          |> put_flash(:error, message)
          |> redirect(to: ~p"/login")

        {:halt, socket}
    end
  end
end
