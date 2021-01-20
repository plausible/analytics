import Config

config :plausible, PlausibleWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  check_origin: false,
  server: true,
  session_cookie_extra: "SameSite=Lax",
  code_reloader: false
