defmodule PlausibleWeb.LiveSocket do
  use Phoenix.LiveView.Socket
  require Logger

  def connect(params, %Phoenix.Socket{} = socket, connect_info) do
    case Phoenix.LiveView.Socket.connect(params, socket, connect_info) do
      {:ok, %Phoenix.Socket{private: %{connect_info: %{session: nil}}}} ->
        Logger.error("Could not connect the live socket: no session found")
        {:error, :socket_auth_error}

      other ->
        other
    end
  end
end
