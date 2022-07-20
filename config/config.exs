import Config

config :plausible,
  ecto_repos: [Plausible.Repo, Plausible.ClickhouseRepo]

config :plausible, PlausibleWeb.Endpoint, pubsub_server: Plausible.PubSub

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

config :plausible, Plausible.ClickhouseRepo, loggers: [Ecto.LogEntry]

config :plausible, Plausible.Repo,
  timeout: 300_000,
  connect_timeout: 300_000,
  handshake_timeout: 300_000

config :plausible, :user_agent_cache,
  limit: 1000,
  stats: false

config :esbuild,
  version: "0.14.41",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.1.6",
  default: [
    args: ~w(
    --config=tailwind.config.js
    --input=css/app.css
    --output=../priv/static/assets/app.css
  ),
    cd: Path.expand("../assets", __DIR__)
  ]

import_config "#{config_env()}.exs"
