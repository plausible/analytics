import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :plausible, PlausibleWeb.Endpoint, server: false

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

config :plausible,
  dns_lookup_impl: Plausible.DnsLookup.Mock

config :plausible, Plausible.Cache, enabled: false

config :ex_money, api_module: Plausible.ExchangeRateMock

config :plausible, Plausible.Ingestion.Counters, enabled: false

config :plausible, Oban, testing: :manual

config :plausible, Plausible.InstallationSupport.Checks.FetchBody,
  req_opts: [
    plug: {Req.Test, Plausible.InstallationSupport.Checks.FetchBody}
  ]

config :plausible, Plausible.InstallationSupport.Checks.Installation,
  req_opts: [
    plug: {Req.Test, Plausible.InstallationSupport.Checks.Installation}
  ]

config :plausible, Plausible.HelpScout,
  req_opts: [
    plug: {Req.Test, Plausible.HelpScout}
  ]

config :plausible, Plausible.InstallationSupport.Checks.Detection,
  req_opts: [
    plug: {Req.Test, :global}
  ]

config :plausible, Plausible.InstallationSupport.Checks.InstallationV2,
  req_opts: [
    plug: {Req.Test, Plausible.InstallationSupport.Checks.InstallationV2}
  ]

config :plausible, Plausible.Session.Salts, interval: :timer.hours(1)
