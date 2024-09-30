defmodule PlausibleWeb.Dogfood do
  @moduledoc """
  Plausible tracking itself functions
  """

  @doc """
  Temporary override to do more testing of the new ingest.plausible.io endpoint for accepting events. In staging and locally
  will fall back to staging.plausible.io/api/event and localhost:8000/api/event respectively.
  """
  def api_destination() do
    if Application.get_env(:plausible, :environment) == "prod" do
      "https://ingest.plausible.io/api/event"
    end
  end

  def script_url() do
    if Application.get_env(:plausible, :environment) in ["prod", "staging"] do
      "#{PlausibleWeb.Endpoint.url()}/js/script.manual.pageview-props.tagged-events.pageleave.js"
    else
      "#{PlausibleWeb.Endpoint.url()}/js/script.local.manual.pageview-props.tagged-events.pageleave.js"
    end
  end

  def domain(conn) do
    cond do
      Application.get_env(:plausible, :is_selfhost) -> "ee.plausible.io"
      conn.assigns[:embedded] -> "embed." <> PlausibleWeb.Endpoint.host()
      true -> PlausibleWeb.Endpoint.host()
    end
  end
end
