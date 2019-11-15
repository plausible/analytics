# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :plausible,
  ecto_repos: [Plausible.Repo]

# Configures the endpoint
config :plausible, PlausibleWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "/NJrhNtbyCVAsTyvtk1ZYCwfm981Vpo/0XrVwjJvemDaKC/vsvBRevLwsc6u8RCg",
  render_errors: [
    view: PlausibleWeb.ErrorView,
    accepts: ~w(html json)
  ],
  pubsub: [name: Plausible.PubSub, adapter: Phoenix.PubSub.PG2]

config :sentry,
  dsn: "https://0350a42aa6234a2eaf1230866788598e@sentry.io/1382353",
  included_environments: [:prod, :staging],
  environment_name: String.to_atom(Map.get(System.get_env(), "APP_ENV", "dev")),
  enable_source_code_context: true,
  root_source_code_path: File.cwd!

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
  paddle_api: Plausible.Billing.PaddleApi

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
