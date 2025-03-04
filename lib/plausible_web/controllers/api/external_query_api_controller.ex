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
        # :TODO: This could use `set_include` instead (if unset)
        query =
          Query.set(query,
            time_on_page_combined_data: %{
              include_new_metric: true,
              include_legacy_metric: false
            }
          )

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
end
