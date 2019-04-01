use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with webpack to recompile .js and .css sources.
config :plausible, PlausibleWeb.Endpoint,
  http: [port: 8000],
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
  ]

config :plausible, PlausibleWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/plausible_web/views/.*(ex)$},
      ~r{lib/plausible_web/templates/.*(eex)$}
    ]
  ]

config :logger, :console, format: "[$level] $message\n"
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

config :plausible, Plausible.Repo,
  username: "postgres",
  password: "postgres",
  database: "plausible_dev",
  hostname: "localhost",
  pool_size: 10

config :plausible, Plausible.Mailer,
  adapter: Bamboo.PostmarkAdapter,
  api_key: "7007fc38-e1b4-44c4-b843-82f58b53fade"

  #config :plausible, Plausible.Mailer,
  #  adapter: Bamboo.LocalAdapter

config :plausible, :amplitude,
  api_key: "a2de0688a23355c0c332ee9a8707bbcd"
