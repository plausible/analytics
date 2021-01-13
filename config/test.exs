import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :plausible, PlausibleWeb.Endpoint, server: false

config :bcrypt_elixir, :log_rounds, 4

config :plausible, Plausible.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  url: "postgres://postgres:postgres@127.0.0.1:5432/plausible_test"

config :plausible, Plausible.ClickhouseRepo,
  loggers: [Ecto.LogEntry],
  pool_size: 5

config :plausible, Plausible.Mailer, adapter: Bamboo.TestAdapter

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
  session_timeout: 0
