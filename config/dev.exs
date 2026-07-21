import Config

config :plausible, PlausibleWeb.Endpoint,
  server: true,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]},
    npm: ["--prefix", "assets", "run", "typecheck", "--", "--watch", "--preserveWatchOutput"],
    npm: [
      "run",
      "deploy",
      cd: Path.expand("../tracker", __DIR__)
    ]
  ],
  live_reload: [
    dirs: [
      "extra"
    ],
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r"lib/plausible_web/(controllers|live|components|templates|views|plugs)/.*(ex|heex)$"
    ]
  ]

config :plausible, paddle_api: Plausible.Billing.DevPaddleApiMock

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

config :plausible, Plausible.Repo, stacktrace: true
config :plausible, Plausible.ClickhouseRepo, stacktrace: true
config :plausible, Plausible.IngestRepo, stacktrace: true
config :plausible, Plausible.AsyncInsertRepo, stacktrace: true

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true

# Development-only: wire the MCP/OAuth CIMD fetcher so the connector flow can be
# tested locally before the shared SSRF-safe HTTP helper lands. This fetcher has
# NO SSRF protection and must never be enabled outside dev (it raises in prod).
# The MCP surface is additionally gated by the off-by-default :mcp_server flag.
config :plausible, Plausible.OAuth,
  client_metadata_fetcher: Plausible.OAuth.DevClientMetadataFetcher
