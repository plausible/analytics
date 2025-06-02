import Config

config :plausible, PlausibleWeb.Endpoint,
  server: true,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]},
    storybook_tailwind: {Tailwind, :install_and_run, [:storybook, ~w(--watch)]},
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
      ~r"lib/plausible_web/(controllers|live|components|templates|views|plugs)/.*(ex|heex)$",
      ~r"storybook/.*(exs)$"
    ]
  ]

config :plausible, PlausibleWeb.InternalEndpoint,
  server: true,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  live_reload: [
    dirs: [
      "extra"
    ],
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r"lib/plausible_web/(controllers|live|components|templates|views|plugs)/.*(ex|heex)$",
      ~r"storybook/.*(exs)$"
    ]
  ]

config :plausible, paddle_api: Plausible.Billing.DevPaddleApiMock

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
