defmodule Plausible.PromEx do
  use PromEx, otp_app: :plausible

  alias PromEx.Plugins

  @impl true
  def plugins do
    [
      Plugins.Application,
      Plugins.Beam,
      Plugins.PhoenixLiveView,
      {Plugins.Phoenix, router: PlausibleWeb.Router, endpoint: PlausibleWeb.Endpoint},
      {Plugins.Ecto,
       repos: [
         Plausible.Repo,
         Plausible.ClickhouseRepo,
         Plausible.IngestRepo,
         Plausible.AsyncInsertRepo
       ]},
      Plugins.Oban,
      Plausible.PromEx.Plugins.PlausibleMetrics
    ]
  end

  @impl true
  def dashboard_assigns do
    [
      datasource_id: "grafanacloud-prom",
      default_selected_interval: "30s"
    ]
  end

  @impl true
  def dashboards do
    [
      {:prom_ex, "application.json"},
      {:prom_ex, "beam.json"},
      {:prom_ex, "phoenix.json"},
      {:prom_ex, "ecto.json"},
      {:prom_ex, "oban.json"}
    ]
  end
end
