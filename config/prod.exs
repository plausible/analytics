use Mix.Config

config :plausible, PlausibleWeb.Endpoint,
  http: [:inet6, port: System.get_env("PORT") || 4000],
  url: [host: System.get_env("HOST"), scheme: "https", port: 443],
  cache_static_manifest: "priv/static/cache_manifest.json"

# Do not print debug messages in production
config :logger, level: :info


# For the actual-production deployments we will use releases,
# i.e., "releases.exs" is the _actual_ production config
# see "releases.exs"

import_config "releases.exs"
