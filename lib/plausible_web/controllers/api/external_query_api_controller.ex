defmodule PlausibleWeb.Api.ExternalQueryApiController do
  @moduledoc false

  use PlausibleWeb, :controller
  use Plausible.Repo
  use PlausibleWeb.Plugs.ErrorHandler
  alias Plausible.Stats.Query

  def query(conn, params) do
    # Temporary - instead of passing the user down to QueryParser, check the
    # scroll depth feature flag here.
    if passes_scroll_depth_feature_gate?(params, conn.assigns) do
      site = Repo.preload(conn.assigns.site, :owner)

      case Query.build(site, conn.assigns.schema_type, params, debug_metadata(conn)) do
        {:ok, query} ->
          results = Plausible.Stats.query(site, query)
          json(conn, results)

        {:error, message} ->
          conn
          |> put_status(400)
          |> json(%{error: message})
      end
    else
      conn
      |> put_status(400)
      |> json(%{error: "Invalid metric \"scroll depth\""})
    end
  end

  # Also temporary - Since the scroll_depth metric is private, there's no need
  # to expose it in the public schema.
  @schema_without_scroll_depth Plausible.Stats.JSONSchema.raw_public_schema()
                               |> Plausible.Stats.JSONSchema.Utils.traverse(fn
                                 %{"const" => "scroll_depth"} -> :remove
                                 value -> value
                               end)

  def schema(conn, _params) do
    json(conn, @schema_without_scroll_depth)
  end

  defp passes_scroll_depth_feature_gate?(params, assigns) do
    metrics = params["metrics"]
    user = assigns[:current_user]

    scroll_depth_queried? = is_list(metrics) and "scroll_depth" in metrics
    scroll_depth_enabled? = user && FunWithFlags.enabled?(:scroll_depth, for: user)

    if scroll_depth_queried?, do: scroll_depth_enabled?, else: true
  end
end
