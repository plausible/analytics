import Config

import_config "dev.exs"

config :esbuild,
  default: [
    args:
      ~w(js/app.js js/dashboard.tsx js/embed.host.js js/embed.content.js --bundle --target=es2017 --loader:.js=jsx --outdir=../priv/static/js --define:BUILD_EXTRA=false),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]
