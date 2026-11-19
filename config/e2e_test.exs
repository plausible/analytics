import Config

config :plausible, PlausibleWeb.Endpoint,
  server: true,
  check_origin: false

config :plausible,
  paddle_classic_api: Plausible.Billing.PaddleClassic.DevApiMock,
  google_api: Plausible.Google.API.Mock,
  verification_checks_mod: Plausible.InstallationSupport.Verification.ChecksMock

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

config :bcrypt_elixir, :log_rounds, 4

config :plausible, Plausible.Ingestion.Counters, enabled: false

config :plausible, Oban, testing: :manual

config :plausible, Plausible.Session.Salts, interval: :timer.hours(1)

# Browser suite in e2e/ (playwright_ex). The app runs in the test VM. The device and
# base_url are set in runtime.exs.
config :playwright, :test,
  # Collect trace when retrying the failed test
  trace: :on_first_retry

if System.get_env("CI"), do: config(:playwright, :test, workers: 4)
