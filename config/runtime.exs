import Config

if config_env() in [:dev, :test] do
  Envy.auto_load()
end

port = System.get_env("PORT") || 8000

base_url =
  System.get_env("BASE_URL", "http://localhost:8000")
  |> URI.parse()

secret_key_base = System.get_env("SECRET_KEY_BASE")

db_url =
  System.get_env(
    "DATABASE_URL",
    "postgres://postgres:postgres@plausible_db:5432/plausible_db"
  )

admin_user = System.get_env("ADMIN_USER_NAME")
admin_email = System.get_env("ADMIN_USER_EMAIL")
admin_emails = System.get_env("ADMIN_EMAILS", "") |> String.split(",")
admin_pwd = System.get_env("ADMIN_USER_PWD")
env = System.get_env("ENVIRONMENT", "prod")
mailer_adapter = System.get_env("MAILER_ADAPTER", "Bamboo.SMTPAdapter")
mailer_email = System.get_env("MAILER_EMAIL", "hello@plausible.local")
app_version = System.get_env("APP_VERSION", "0.0.1")

ch_db_url =
  System.get_env("CLICKHOUSE_DATABASE_URL", "http://plausible_events_db:8123/plausible_events_db")

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
hcaptcha_sitekey = System.get_env("HCAPTCHA_SITEKEY")
hcaptcha_secret = System.get_env("HCAPTCHA_SECRET")
log_level = String.to_existing_atom(System.get_env("LOG_LEVEL", "warn"))
appsignal_api_key = System.get_env("APPSIGNAL_API_KEY")

{user_agent_cache_limit, ""} = Integer.parse(System.get_env("USER_AGENT_CACHE_LIMIT", "1000"))

user_agent_cache_stats =
  String.to_existing_atom(System.get_env("USER_AGENT_CACHE_STATS", "false"))

config :plausible,
  admin_user: admin_user,
  admin_email: admin_email,
  admin_pwd: admin_pwd,
  environment: env,
  mailer_email: mailer_email,
  admin_emails: admin_emails

config :plausible, :selfhost,
  disable_authentication: disable_auth,
  disable_subscription: String.to_existing_atom(System.get_env("DISABLE_SUBSCRIPTION", "true")),
  disable_registration:
    if(!disable_auth,
      do: String.to_existing_atom(System.get_env("DISABLE_REGISTRATION", "false")),
      else: false
    )

config :plausible, PlausibleWeb.Endpoint,
  url: [host: base_url.host, scheme: base_url.scheme, port: base_url.port],
  http: [port: port],
  secret_key_base: secret_key_base

config :plausible, Plausible.Repo, url: db_url

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

config :plausible, Plausible.ClickhouseRepo,
  loggers: [Ecto.LogEntry],
  url: ch_db_url

case mailer_adapter do
  "Bamboo.PostmarkAdapter" ->
    config :plausible, Plausible.Mailer,
      adapter: :"Elixir.#{mailer_adapter}",
      request_options: [recv_timeout: 10_000],
      api_key: System.get_env("POSTMARK_API_KEY")

  "Bamboo.SMTPAdapter" ->
    config :plausible, Plausible.Mailer,
      adapter: :"Elixir.#{mailer_adapter}",
      server: System.get_env("SMTP_HOST_ADDR", "mail"),
      hostname: base_url.host,
      port: System.get_env("SMTP_HOST_PORT", "25"),
      username: System.get_env("SMTP_USER_NAME"),
      password: System.get_env("SMTP_USER_PWD"),
      tls: :if_available,
      allowed_tls_versions: [:tlsv1, :"tlsv1.1", :"tlsv1.2"],
      ssl: System.get_env("SMTP_HOST_SSL_ENABLED") || false,
      retries: System.get_env("SMTP_RETRIES") || 2,
      no_mx_lookups: System.get_env("SMTP_MX_LOOKUPS_ENABLED") || true

  "Bamboo.LocalAdapter" ->
    config :plausible, Plausible.Mailer, adapter: Bamboo.LocalAdapter

  "Bamboo.TestAdapter" ->
    config :plausible, Plausible.Mailer, adapter: Bamboo.TestAdapter

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

if config_env() !== :test do
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
    {"*/10 * * * *", Plausible.Workers.ProvisionSslCertificates},
    # Every 15 minutes
    {"*/15 * * * *", Plausible.Workers.SpikeNotifier},
    # Every day at midnight
    {"0 0 * * *", Plausible.Workers.CleanEmailVerificationCodes}
  ]

  base_queues = [rotate_salts: 1]

  extra_queues = [
    provision_ssl_certificates: 1,
    fetch_tweets: 1,
    check_stats_emails: 1,
    site_setup_emails: 1,
    trial_notification_emails: 1,
    schedule_email_reports: 1,
    send_email_reports: 1,
    spike_notifications: 1,
    clean_email_verification_codes: 1
  ]

  config :plausible, Oban,
    repo: Plausible.Repo,
    queues: if(cron_enabled, do: base_queues ++ extra_queues, else: base_queues),
    crontab: if(cron_enabled, do: base_cron ++ extra_cron, else: base_cron)
end

config :plausible, :hcaptcha,
  sitekey: hcaptcha_sitekey,
  secret: hcaptcha_secret

config :ref_inspector,
  init: {Plausible.Release, :configure_ref_inspector}

config :ua_inspector,
  init: {Plausible.Release, :configure_ua_inspector}

config :plausible, :user_agent_cache,
  limit: user_agent_cache_limit,
  stats: user_agent_cache_stats

config :kaffy,
  otp_app: :plausible,
  ecto_repo: Plausible.Repo,
  router: PlausibleWeb.Router,
  admin_title: "Plausible Admin",
  resources: [
    auth: [
      resources: [
        user: [schema: Plausible.Auth.User, admin: Plausible.Auth.UserAdmin]
      ]
    ],
    sites: [
      resources: [
        site: [schema: Plausible.Site, admin: Plausible.SiteAdmin]
      ]
    ]
  ]

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

config :logger, level: log_level

if appsignal_api_key do
  config :appsignal, :config,
    otp_app: :plausible,
    name: "Plausible Analytics",
    push_api_key: appsignal_api_key,
    env: env,
    active: true
end
