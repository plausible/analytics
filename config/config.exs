# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :neatmetrics,
  ecto_repos: [Neatmetrics.Repo]

# Configures the endpoint
config :neatmetrics, NeatmetricsWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "/NJrhNtbyCVAsTyvtk1ZYCwfm981Vpo/0XrVwjJvemDaKC/vsvBRevLwsc6u8RCg",
  render_errors: [view: NeatmetricsWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Neatmetrics.PubSub, adapter: Phoenix.PubSub.PG2]

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

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
