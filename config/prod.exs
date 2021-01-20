import Config

config :plausible, PlausibleWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  check_origin: false,
  server: true,
  allow_embed: false,
  code_reloader: false
