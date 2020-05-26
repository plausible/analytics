import Config

### Mandatory params Start
# it is highly recommended to change this parameters in production systems
# params are made optional to facilitate smooth release

port = System.get_env("PORT") || 8000
host = System.get_env("HOST", "localhost")

secret_key_base =
  System.get_env(
    "SECRET_KEY_BASE",
    "/NJrhNtbyCVAsTyvtk1ZYCwfm981Vpo/0XrVwjJvemDaKC/vsvBRevLwsc6u8RCg"
  )

db_pool_size = String.to_integer(System.get_env("DATABASE_POOL_SIZE", "10"))

db_url =
  System.get_env(
    "DATABASE_URL",
    "postgres://postgres:postgres@127.0.0.1:5432/plausible_test?currentSchema=default"
  )

db_tls_enabled? = String.to_existing_atom(System.get_env("DATABASE_TLS_ENABLED", "false"))
admin_user = System.get_env("ADMIN_USER_NAME")
admin_email = System.get_env("ADMIN_USER_EMAIL")
admin_pwd = System.get_env("ADMIN_USER_PWD")
env = System.get_env("ENVIRONMENT", "prod")
mailer_adapter = System.get_env("MAILER_ADAPTER", "Bamboo.PostmarkAdapter")
mailer_email = System.get_env("MAILER_EMAIL", "hello@plausible.local")
app_version = System.get_env("APP_VERSION", "0.0.1")
ck_host = System.get_env("CLICKHOUSE_DATABASE_HOST", "localhost")
ck_db = System.get_env("CLICKHOUSE_DATABASE_NAME", "plausible_dev")
ck_db_user = System.get_env("CLICKHOUSE_DATABASE_USER")
ck_db_pwd = System.get_env("CLICKHOUSE_DATABASE_PASSWORD")
ck_db_pool = System.get_env("CLICKHOUSE_DATABASE_POOLSIZE") || 10
### Mandatory params End

sentry_dsn = System.get_env("SENTRY_DSN")
paddle_auth_code = System.get_env("PADDLE_VENDOR_AUTH_CODE")
google_cid = System.get_env("GOOGLE_CLIENT_ID")
google_secret = System.get_env("GOOGLE_CLIENT_SECRET")
slack_hook_url = System.get_env("SLACK_WEBHOOK")
twitter_consumer_key = System.get_env("TWITTER_CONSUMER_KEY")
twitter_consumer_secret = System.get_env("TWITTER_CONSUMER_SECRET")
twitter_token = System.get_env("TWITTER_ACCESS_TOKEN")
twitter_token_secret = System.get_env("TWITTER_ACCESS_TOKEN_SECRET")
postmark_api_key = System.get_env("POSTMARK_API_KEY")

config :plausible,
  admin_user: admin_user,
  admin_email: admin_email,
  admin_pwd: admin_pwd,
  environment: env,
  mailer_email: mailer_email

config :plausible, PlausibleWeb.Endpoint,
  url: [host: host, port: port],
  http: [
    port: port
  ],
  secret_key_base: secret_key_base,
  cache_static_manifest: "priv/static/cache_manifest.json",
  check_origin: false,
  load_from_system_env: true,
  server: true,
  code_reloader: false

config :plausible,
       Plausible.Repo,
       pool_size: db_pool_size,
       url: db_url,
       adapter: Ecto.Adapters.Postgres,
       ssl: db_tls_enabled?

config :sentry,
  dsn: sentry_dsn,
  environment_name: env,
  release: app_version,
  tags: %{app_version: app_version}

config :plausible, :paddle, vendor_auth_code: paddle_auth_code

config :plausible, :google,
  client_id: google_cid,
  client_secret: google_secret

config :plausible, :slack, webhook: slack_hook_url

config :plausible, :clickhouse,
       hostname: ck_host,
       database: ck_db,
       username: ck_db_user,
       password: ck_db_pwd,
       pool_size: ck_db_pool

case mailer_adapter do
  "Bamboo.PostmarkAdapter" ->
    config :plausible, Plausible.Mailer,
      adapter: :"Elixir.#{mailer_adapter}",
      api_key: System.get_env("POSTMARK_API_KEY")

  "Bamboo.SMTPAdapter" ->
    config :plausible, Plausible.Mailer,
      adapter: :"Elixir.#{mailer_adapter}",
      server: System.fetch_env!("SMTP_HOST_ADDR"),
      hostname: System.get_env("HOST", "localhost"),
      port: System.fetch_env!("SMTP_HOST_PORT"),
      username: System.fetch_env!("SMTP_USER_NAME"),
      password: System.fetch_env!("SMTP_USER_PWD"),
      tls: :if_available,
      allowed_tls_versions: [:tlsv1, :"tlsv1.1", :"tlsv1.2"],
      ssl: System.get_env("SMTP_HOST_SSL_ENABLED") || true,
      retries: System.get_env("SMTP_RETRIES") || 2,
      no_mx_lookups: System.get_env("SMTP_MX_LOOKUPS_ENABLED") || true,
      auth: :always

  _ ->
    raise "Unknown mailer_adapter; expected SMTPAdapter or PostmarkAdapter"
end

config :plausible, :twitter,
  consumer_key: twitter_consumer_key,
  consumer_secret: twitter_consumer_secret,
  token: twitter_token,
  token_secret: twitter_token_secret

config :logger, level: :warn
