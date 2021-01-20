import Config

config :plausible, PlausibleWeb.Endpoint,
  render_errors: [
    view: PlausibleWeb.ErrorView,
    accepts: ~w(html json)
  ],
  server: true,
  allow_embed: false,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch-stdin",
      cd: Path.expand("../assets", __DIR__)
    ]
  ],
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/plausible_web/views/.*(ex)$},
      ~r{lib/plausible_web/templates/.*(eex)$},
      ~r{lib/plausible_web/controllers/.*(ex)$},
      ~r{lib/plausible_web/plugs/.*(ex)$}
    ]
  ]

config :logger, :console, format: "[$level] $message\n"
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
