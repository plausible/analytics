import Config

config :plausible, PlausibleWeb.Endpoint,
  server: true,
  check_origin: false

config :bcrypt_elixir, :log_rounds, 4

config :plausible, Plausible.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :plausible, Plausible.ClickhouseRepo,
  loggers: [Ecto.LogEntry],
  pool_size: 15

config :ex_money, api_module: Plausible.ExchangeRateMock
