import Config

config :plausible,
  ecto_repos: [Plausible.Repo, Plausible.IngestRepo]

config :plausible, PlausibleWeb.Endpoint,
  pubsub_server: Plausible.PubSub,
  render_errors: [
    view: PlausibleWeb.ErrorView,
    layout: {PlausibleWeb.LayoutView, "focus.html"},
    accepts: ~w(html json)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :ua_inspector,
  database_path: "priv/ua_inspector"

config :ref_inspector,
  database_path: "priv/ref_inspector"

config :plausible,
  paddle_api: Plausible.Billing.PaddleApi,
  google_api: Plausible.Google.Api

config :plausible,
  # 30 minutes
  session_timeout: 1000 * 60 * 30,
  session_length_minutes: 30

config :fun_with_flags, :cache_bust_notifications, enabled: false

config :fun_with_flags, :persistence,
  adapter: FunWithFlags.Store.Persistent.Ecto,
  repo: Plausible.Repo

config :plausible, Plausible.ClickhouseRepo, loggers: [Ecto.LogEntry]

config :plausible, Plausible.Repo,
  timeout: 300_000,
  connect_timeout: 300_000,
  handshake_timeout: 300_000

config :plausible,
  sites_by_domain_cache_enabled: true,
  sites_by_domain_cache_refresh_interval_max_jitter: :timer.seconds(5),
  sites_by_domain_cache_refresh_interval: :timer.minutes(15)

config :plausible, Plausible.Ingestion.Counters, enabled: true

import_config "#{config_env()}.exs"
