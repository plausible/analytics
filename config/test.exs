import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :plausible, PlausibleWeb.Endpoint, server: false
config :plausible, PlausibleWeb.InternalEndpoint, server: false

config :bcrypt_elixir, :log_rounds, 4

config :plausible, Plausible.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :plausible, Plausible.ClickhouseRepo,
  loggers: [Ecto.LogEntry],
  pool_size: 15

config :plausible, Plausible.Mailer, adapter: Bamboo.TestAdapter

config :plausible,
  paddle_api: Plausible.Billing.TestPaddleApiMock,
  google_api: Plausible.Google.API.Mock

config :bamboo, :refute_timeout, 10

config :plausible,
  session_timeout: 0,
  http_impl: Plausible.HTTPClient.Mock

config :plausible, Plausible.Cache, enabled: false

config :ex_money, api_module: Plausible.ExchangeRateMock

config :plausible, Plausible.Ingestion.Counters, enabled: false

config :plausible, Oban, testing: :manual

config :plausible, Plausible.Verification.Checks.FetchBody,
  req_opts: [
    plug: {Req.Test, Plausible.Verification.Checks.FetchBody}
  ]

config :plausible, Plausible.Verification.Checks.Installation,
  req_opts: [
    plug: {Req.Test, Plausible.Verification.Checks.Installation}
  ]

config :plausible, Plausible.HelpScout,
  req_opts: [
    plug: {Req.Test, Plausible.HelpScout}
  ]
