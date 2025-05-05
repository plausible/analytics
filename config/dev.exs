import Config

config :plausible, PlausibleWeb.Endpoint,
  server: true,
  debug_errors: true,
  code_reloader: false,
  check_origin: false

config :plausible, paddle_api: Plausible.Billing.DevPaddleApiMock

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
