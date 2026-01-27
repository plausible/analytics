import Config

config :wallaby, otp_app: :plausible, screenshot_on_failure: true

config :plausible, PlausibleWeb.Endpoint,
  server: true,
  check_origin: false

config :plausible, paddle_api: Plausible.Billing.DevPaddleApiMock

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

config :bcrypt_elixir, :log_rounds, 4

config :plausible, Plausible.Ingestion.Counters, enabled: false

config :plausible, Oban, testing: :manual

config :plausible, Plausible.Session.Salts, interval: :timer.hours(1)
