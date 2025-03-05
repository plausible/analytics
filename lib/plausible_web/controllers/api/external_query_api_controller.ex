defmodule PlausibleWeb.Api.ExternalQueryApiController do
  @moduledoc false

  use PlausibleWeb, :controller
  use Plausible.Repo
  use PlausibleWeb.Plugs.ErrorHandler
  alias Plausible.Stats.Query

  def query(conn, params) do
    site = Repo.preload(conn.assigns.site, :owners)

    case Query.build(site, conn.assigns.schema_type, params, debug_metadata(conn)) do
      {:ok, query} ->
        query = update_time_on_page_query_data(query)

        results = Plausible.Stats.query(site, query)
        json(conn, results)

      {:error, message} ->
        conn
        |> put_status(400)
        |> json(%{error: message})
    end
  end

  def schema(conn, _params) do
    json(conn, Plausible.Stats.JSONSchema.raw_public_schema())
  end

  defp update_time_on_page_query_data(query) do
    if is_nil(query.include.legacy_time_on_page_cutoff) do
      Query.set(query,
        time_on_page_data: %{
          include_new_metric: true,
          include_legacy_metric: false,
          cutoff: nil
        }
      )
    else
      query
    end
  end
end
