defmodule PlausibleWeb.Api.ExternalQueryApiController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  use PlausibleWeb.Plugs.ErrorHandler
  alias Plausible.Stats.Query

  def query(conn, params) do
    IO.inspect(params)
    site = Repo.preload(conn.assigns.site, :owner)

    with {:ok, query} <- Query.build(site, params) do
      results = Plausible.Stats.query(site, query)
      json(conn, results)
    else
      err_tuple ->
        send_json_error_response(conn, err_tuple)
    end
  end

  defp send_json_error_response(conn, {:error, {status, msg}}) do
    conn
    |> put_status(status)
    |> json(%{error: msg})
  end

  defp send_json_error_response(conn, {:error, msg}) do
    IO.inspect({:error, msg})

    conn
    |> put_status(400)
    |> json(%{error: msg})
  end
end
