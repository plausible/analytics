import Config

import_config "prod.exs"

config :phoenix,
  static_compressors: [
    PhoenixBakery.Gzip,
    PhoenixBakery.Brotli
  ]

config :esbuild,
  default: [
    args:
      ~w(js/app.js js/dashboard.tsx js/embed.host.js js/embed.content.js --bundle --target=es2017 --loader:.js=jsx --outdir=../priv/static/js --define:BUILD_EXTRA=false),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :plausible, Plausible.Auth.ApiKey, legacy_per_user_hourly_request_limit: 1_000_000
