use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :plausible, PlausibleWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Reduce bcrypt rounds to speed up test suite
config :bcrypt_elixir, :log_rounds, 4

# Configure your database
config :plausible,
       Plausible.Repo,
       url:
         System.get_env(
           "DATABASE_URL",
           "postgres://postgres:postgres@127.0.0.1:5432/plausible_test=default"
         ),
       pool: Ecto.Adapters.SQL.Sandbox

config :plausible, :clickhouse,
  hostname: System.get_env("CLICKHOUSE_DATABASE_HOST", "localhost"),
  database: System.get_env("CLICKHOUSE_DATABASE_NAME", "plausible_test"),
  username: System.get_env("CLICKHOUSE_DATABASE_USER"),
  password: System.get_env("CLICKHOUSE_DATABASE_PASSWORD"),
  pool_size: 10

config :plausible, Plausible.Mailer, adapter: Bamboo.TestAdapter

config :plausible, Oban, crontab: false, queues: false

config :plausible,
  paddle_api: Plausible.PaddleApi.Mock,
  google_api: Plausible.Google.Api.Mock

config :junit_formatter,
  report_file: "report.xml",
  report_dir: File.cwd!(),
  print_report_file: true,
  prepend_project_name?: true,
  include_filename?: true

config :geolix,
  databases: [
    %{
      id: :country,
      adapter: Geolix.Adapter.Fake,
      data: %{{1, 1, 1, 1} => %{country: %{iso_code: "US"}}}
    }
  ]

config :plausible,
  session_timeout: 0,
  environment: System.get_env("ENVIRONMENT", "test")
