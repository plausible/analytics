import Config

config :plausible, PlausibleWeb.Endpoint,
  server: true,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]},
    npm: [
      "run",
      "deploy",
      cd: Path.expand("../tracker", __DIR__)
    ]
  ],
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{lib/plausible_web/views/.*(ex)$},
      ~r{lib/plausible_web/templates/.*(eex)$},
      ~r{lib/plausible_web/templates/.*(heex)$},
      ~r{lib/plausible_web/controllers/.*(ex)$},
      ~r{lib/plausible_web/plugs/.*(ex)$},
      ~r{lib/plausible_web/live/.*(ex)$}
    ]
  ]

config :logger, :console, format: "[$level] $message\n"
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
