defmodule PlausibleWeb.Api.ExternalQueryApiController do
  @moduledoc false

  use PlausibleWeb, :controller
  use Plausible.Repo
  use PlausibleWeb.Plugs.ErrorHandler
  alias Plausible.Stats.Query

  def query(conn, params) do
    site = Repo.preload(conn.assigns.site, :owner)

    case Query.build(site, params, debug_metadata(conn)) do
      {:ok, query} ->
        results = Plausible.Stats.query(site, query)
        json(conn, results)

      {:error, message} ->
        conn
        |> put_status(400)
        |> json(%{error: message})
    end
  end
end
