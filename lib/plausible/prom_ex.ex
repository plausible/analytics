defmodule Plausible.PromEx do
  use PromEx, otp_app: :plausible

  alias PromEx.Plugins

  @plugins [
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
    Plausible.PromEx.Plugins.PlausibleMetrics
  ]

  @impl true
  if Mix.env() in [:test, :ce_test] do
    # PromEx tries to query Oban's DB tables in order to retrieve metrics.
    # During tests, however, this is pointless as Oban is in manual mode,
    # and that leads to connection ownership clashes.
    def plugins do
      @plugins
    end
  else
    def plugins do
      [Plugins.Oban | @plugins]
    end
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
