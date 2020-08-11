import Config

### Mandatory params Start
# it is highly recommended to change this parameters in production systems
# params are made optional to facilitate smooth release

port = System.get_env("PORT") || 8000
host = System.get_env("HOST", "localhost")
scheme = System.get_env("SCHEME", "http")

secret_key_base =
  System.get_env(
    "SECRET_KEY_BASE",
    "/NJrhNtbyCVAsTyvtk1ZYCwfm981Vpo/0XrVwjJvemDaKC/vsvBRevLwsc6u8RCg"
  )

db_pool_size = String.to_integer(System.get_env("DATABASE_POOLSIZE", "10"))

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
ck_db_pool = String.to_integer(System.get_env("CLICKHOUSE_DATABASE_POOLSIZE", "10"))
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
cron_enabled = String.to_existing_atom(System.get_env("CRON_ENABLED", "false"))
custom_domain_server_ip = System.get_env("CUSTOM_DOMAIN_SERVER_IP")
custom_domain_server_user = System.get_env("CUSTOM_DOMAIN_SERVER_USER")
custom_domain_server_password = System.get_env("CUSTOM_DOMAIN_SERVER_PASSWORD")
geolite2_country_db = System.get_env("GEOLITE2_COUNTRY_DB")
disable_auth = String.to_existing_atom(System.get_env("DISABLE_AUTH", "false"))

config :plausible,
  admin_user: admin_user,
  admin_email: admin_email,
  admin_pwd: admin_pwd,
  environment: env,
  mailer_email: mailer_email

config :plausible, :selfhost,
  disable_authentication: disable_auth,
  disable_subscription: String.to_existing_atom(System.get_env("DISABLE_SUBSCRIPTION", "false")),
  disable_registration:
    if(!disable_auth,
      do: String.to_existing_atom(System.get_env("DISABLE_REGISTRATION", "false")),
      else: false
    )

config :plausible, PlausibleWeb.Endpoint,
  url: [host: host, scheme: scheme],
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
  included_environments: ["prod", "staging"],
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

config :plausible, :custom_domain_server,
  user: custom_domain_server_user,
  password: custom_domain_server_password,
  ip: custom_domain_server_ip

config :plausible, PlausibleWeb.Firewall,
  blocklist: System.get_env("IP_BLOCKLIST", "") |> String.split(",") |> Enum.map(&String.trim/1)

base_cron = [
  # Daily at midnight
  {"0 0 * * *", Plausible.Workers.RotateSalts}
]

extra_cron = [
  # hourly
  {"0 * * * *", Plausible.Workers.SendSiteSetupEmails},
  #  hourly
  {"0 * * * *", Plausible.Workers.ScheduleEmailReports},
  # Daily at midnight
  {"0 0 * * *", Plausible.Workers.FetchTweets},
  # Daily at midday
  {"0 12 * * *", Plausible.Workers.SendTrialNotifications},
  # Daily at midday
  {"0 12 * * *", Plausible.Workers.SendCheckStatsEmails},
  # Every 10 minutes
  {"*/10 * * * *", Plausible.Workers.ProvisionSslCertificates}
]

base_queues = [rotate_salts: 1]

extra_queues = [
  provision_ssl_certificates: 1,
  fetch_tweets: 1,
  check_stats_emails: 1,
  site_setup_emails: 1,
  trial_notification_emails: 1,
  schedule_email_reports: 1,
  send_email_reports: 1
]

config :plausible, Oban,
  repo: Plausible.Repo,
  queues: if(cron_enabled, do: base_queues ++ extra_queues, else: base_queues),
  crontab: if(cron_enabled, do: base_cron ++ extra_cron, else: base_cron)

config :ref_inspector,
  init: {Plausible.Release, :configure_ref_inspector}

config :ua_inspector,
  init: {Plausible.Release, :configure_ua_inspector}

if geolite2_country_db do
  config :geolix,
    databases: [
      %{
        id: :country,
        adapter: Geolix.Adapter.MMDB2,
        source: geolite2_country_db
      }
    ]
end

config :logger, level: :warn
