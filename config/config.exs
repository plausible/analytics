use Mix.Config

config :plausible,
  admin_user: System.get_env("ADMIN_USER_NAME", "admin"),
  admin_email: System.get_env("ADMIN_USER_EMAIL", "admin@plausible.local"),
  admin_pwd: System.get_env("ADMIN_USER_PWD", "!@d3in"),
  ecto_repos: [Plausible.Repo],
  environment: System.get_env(Atom.to_string(Mix.env()), "dev")

# Configures the endpoint
config :plausible, PlausibleWeb.Endpoint,
  url: [
    host: System.get_env("HOST", "localhost"),
    port: String.to_integer(System.get_env("PORT", "8000"))
  ],
  http: [
    port: String.to_integer(System.get_env("PORT", "8000"))
  ],
  secret_key_base:
    System.get_env(
      "SECRET_KEY_BASE",
      "/NJrhNtbyCVAsTyvtk1ZYCwfm981Vpo/0XrVwjJvemDaKC/vsvBRevLwsc6u8RCg"
    ),
  render_errors: [
    view: PlausibleWeb.ErrorView,
    accepts: ~w(html json)
  ],
  pubsub: [name: Plausible.PubSub, adapter: Phoenix.PubSub.PG2]

config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  included_environments: [:prod, :staging],
  environment_name: String.to_atom(Map.get(System.get_env(), "MIX_ENV", "dev")),
  enable_source_code_context: true,
  root_source_code_path: File.cwd!()

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :ua_inspector,
  database_path: "priv/ua_inspector"

config :ref_inspector,
  database_path: "priv/ref_inspector"

config :plausible,
  paddle_api: Plausible.Billing.PaddleApi,
  google_api: Plausible.Google.Api

config :plausible,
  # 30 minutes
  session_timeout: 1000 * 60 * 30

config :plausible, :paddle,
  vendor_id: "49430",
  vendor_auth_code: System.get_env("PADDLE_VENDOR_AUTH_CODE")

config :plausible,
       Plausible.Repo,
       pool_size: String.to_integer(System.get_env("DATABASE_POOL_SIZE", "10")),
       url:
         System.get_env(
           "DATABASE_URL",
           "postgres://postgres:postgres@127.0.0.1:5432/plausible_test?currentSchema=default"
         ),
       ssl: false

config :plausible, :google,
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET")

config :plausible, :slack, webhook: System.get_env("SLACK_WEBHOOK")

config :plausible, Plausible.Mailer,
  adapter: Bamboo.PostmarkAdapter,
  api_key: System.get_env("POSTMARK_API_KEY")

config :plausible, :twitter,
  consumer_key: System.get_env("TWITTER_CONSUMER_KEY"),
  consumer_secret: System.get_env("TWITTER_CONSUMER_SECRET"),
  token: System.get_env("TWITTER_ACCESS_TOKEN"),
  token_secret: System.get_env("TWITTER_ACCESS_TOKEN_SECRET")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
