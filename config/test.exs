import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :plausible, PlausibleWeb.Endpoint, server: false

config :bcrypt_elixir, :log_rounds, 4

config :plausible, Plausible.Repo, pool: Ecto.Adapters.SQL.Sandbox

config :plausible, Plausible.ClickhouseRepo,
  loggers: [Ecto.LogEntry],
  pool_size: 5

config :plausible, Plausible.Mailer, adapter: Bamboo.TestAdapter

config :plausible,
  paddle_api: Plausible.PaddleApi.Mock,
  google_api: Plausible.Google.Api.Mock

config :plausible, :google,
  client_id: "fake_client_id",
  client_secret: "fake_client_secret"

config :bamboo, :refute_timeout, 10

config :plausible,
  session_timeout: 0,
  http_impl: Plausible.HTTPClient.Mock
