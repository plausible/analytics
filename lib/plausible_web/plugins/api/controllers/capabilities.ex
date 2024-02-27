defmodule PlausibleWeb.Plugins.API.Controllers.Capabilities do
  @moduledoc """
  Controller for Plugins API Capabilities - doesn't enforce authentication,
  serves as a comprehensive health check
  """
  use PlausibleWeb, :plugins_api_controller

  operation(:index,
    summary: "Retrieve Capabilities",
    parameters: [],
    responses: %{
      ok: {"Capabilities response", "application/json", Schemas.Capabilities}
    }
  )

  @spec index(Plug.Conn.t(), %{}) :: Plug.Conn.t()
  def index(conn, _params) do
    {:ok, capabilities} = API.Capabilities.get(conn)

    conn
    |> put_view(Views.Capabilities)
    |> render("index.json", capabilities: capabilities)
  end
end
