defmodule PlausibleWeb.Api.ExternalEventsController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  use Plug.ErrorHandler
  alias PlausibleWeb.Api.Helpers, as: H
  alias Plausible.Event.Props, as: EventProps

  def list(conn, _params) do
    site = conn.assigns[:site]
    json(conn, EventProps.props(site))
  end

  def properties(conn, params) do
    site = conn.assigns[:site]

    with {:ok, event_id} <- expect_param_key(params, "event_id") do
      event = Repo.get_by(Plausible.Goal, id: event_id, domain: site.domain)

      if event do
        json(conn, EventProps.props(site, event.event_name))
      else
        H.not_found(conn, "Event could not be found")
      end
    else
      {:missing, "event_id"} ->
        H.bad_request(conn, "Parameter `event_id` is required")

      e ->
        H.bad_request(conn, "Something went wrong: #{inspect(e)}")
    end
  end

  defp expect_param_key(params, key) do
    case Map.fetch(params, key) do
      :error -> {:missing, key}
      res -> res
    end
  end

  def handle_errors(conn, %{kind: kind, reason: reason}) do
    json(conn, %{error: Exception.format_banner(kind, reason)})
  end
end
