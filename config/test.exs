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
       pool: Ecto.Adapters.SQL.Sandbox

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

config :plausible,
       session_timeout: 0
