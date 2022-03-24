import Config
import Plausible.ConfigHelpers

if config_env() in [:dev, :test] do
  Envy.load(["config/.env.#{config_env()}"])
end

config_dir = System.get_env("CONFIG_DIR", "/run/secrets")

# Listen IP supports IPv4 and IPv6 addresses.
listen_ip =
  (
    str = get_var_from_path_or_env(config_dir, "LISTEN_IP") || "127.0.0.1"

    case :inet.parse_address(String.to_charlist(str)) do
      {:ok, ip_addr} ->
        ip_addr

      {:error, reason} ->
        raise "Invalid LISTEN_IP '#{str}' error: #{inspect(reason)}"
    end
  )

# System.get_env does not accept a non string default
port = get_var_from_path_or_env(config_dir, "PORT") || 8000

base_url = get_var_from_path_or_env(config_dir, "BASE_URL")

if !base_url do
  raise "BASE_URL configuration option is required. See https://plausible.io/docs/self-hosting-configuration#server"
end

base_url = URI.parse(base_url)

if base_url.scheme not in ["http", "https"] do
  raise "BASE_URL must start with `http` or `https`. Currently configured as `#{System.get_env("BASE_URL")}`"
end

secret_key_base = get_var_from_path_or_env(config_dir, "SECRET_KEY_BASE", nil)

case secret_key_base do
  nil ->
    raise "SECRET_KEY_BASE configuration option is required. See https://plausible.io/docs/self-hosting-configuration#server"

  key when byte_size(key) < 32 ->
    raise "SECRET_KEY_BASE must be at least 32 bytes long. See https://plausible.io/docs/self-hosting-configuration#server"

  _ ->
    nil
end

db_url =
  get_var_from_path_or_env(
    config_dir,
    "DATABASE_URL",
    "postgres://postgres:postgres@plausible_db:5432/plausible_db"
  )

db_socket_dir = get_var_from_path_or_env(config_dir, "DATABASE_SOCKET_DIR")

admin_user = get_var_from_path_or_env(config_dir, "ADMIN_USER_NAME")
admin_email = get_var_from_path_or_env(config_dir, "ADMIN_USER_EMAIL")

super_admin_user_ids =
  get_var_from_path_or_env(config_dir, "ADMIN_USER_IDS", "")
  |> String.split(",")
  |> Enum.map(fn id -> Integer.parse(id) end)
  |> Enum.map(fn
    {int, ""} -> int
    _ -> nil
  end)
  |> Enum.filter(& &1)

admin_pwd = get_var_from_path_or_env(config_dir, "ADMIN_USER_PWD")
env = get_var_from_path_or_env(config_dir, "ENVIRONMENT", "prod")
mailer_adapter = get_var_from_path_or_env(config_dir, "MAILER_ADAPTER", "Bamboo.SMTPAdapter")
mailer_email = get_var_from_path_or_env(config_dir, "MAILER_EMAIL", "hello@plausible.local")
app_version = get_var_from_path_or_env(config_dir, "APP_VERSION", "0.0.1")

ch_db_url =
  get_var_from_path_or_env(
    config_dir,
    "CLICKHOUSE_DATABASE_URL",
    "http://plausible_events_db:8123/plausible_events_db"
  )

{ch_flush_interval_ms, ""} =
  config_dir
  |> get_var_from_path_or_env("CLICKHOUSE_FLUSH_INTERVAL_MS", "5000")
  |> Integer.parse()

{ch_max_buffer_size, ""} =
  config_dir
  |> get_var_from_path_or_env("CLICKHOUSE_MAX_BUFFER_SIZE", "10000")
  |> Integer.parse()

### Mandatory params End

sentry_dsn = get_var_from_path_or_env(config_dir, "SENTRY_DSN")
honeycomb_api_key = get_var_from_path_or_env(config_dir, "HONEYCOMB_API_KEY")
honeycomb_dataset = get_var_from_path_or_env(config_dir, "HONEYCOMB_DATASET")
paddle_auth_code = get_var_from_path_or_env(config_dir, "PADDLE_VENDOR_AUTH_CODE")
paddle_vendor_id = get_var_from_path_or_env(config_dir, "PADDLE_VENDOR_ID")
google_cid = get_var_from_path_or_env(config_dir, "GOOGLE_CLIENT_ID")
google_secret = get_var_from_path_or_env(config_dir, "GOOGLE_CLIENT_SECRET")
slack_hook_url = get_var_from_path_or_env(config_dir, "SLACK_WEBHOOK")
postmark_api_key = get_var_from_path_or_env(config_dir, "POSTMARK_API_KEY")

cron_enabled =
  config_dir
  |> get_var_from_path_or_env("CRON_ENABLED", "false")
  |> String.to_existing_atom()

geolite2_country_db =
  get_var_from_path_or_env(
    config_dir,
    "GEOLITE2_COUNTRY_DB",
    Application.app_dir(:plausible) <> "/priv/geodb/dbip-country.mmdb"
  )

ip_geolocation_db = get_var_from_path_or_env(config_dir, "IP_GEOLOCATION_DB", geolite2_country_db)
geonames_source_file = get_var_from_path_or_env(config_dir, "GEONAMES_SOURCE_FILE")

disable_auth =
  config_dir
  |> get_var_from_path_or_env("DISABLE_AUTH", "false")
  |> String.to_existing_atom()

enable_email_verification =
  config_dir
  |> get_var_from_path_or_env("ENABLE_EMAIL_VERIFICATION", "false")
  |> String.to_existing_atom()

disable_registration =
  config_dir
  |> get_var_from_path_or_env("DISABLE_REGISTRATION", "false")
  |> String.to_existing_atom()

hcaptcha_sitekey = get_var_from_path_or_env(config_dir, "HCAPTCHA_SITEKEY")
hcaptcha_secret = get_var_from_path_or_env(config_dir, "HCAPTCHA_SECRET")

log_level =
  config_dir
  |> get_var_from_path_or_env("LOG_LEVEL", "warn")
  |> String.to_existing_atom()

domain_blacklist =
  config_dir
  |> get_var_from_path_or_env("DOMAIN_BLACKLIST", "")
  |> String.split(",")

is_selfhost =
  config_dir
  |> get_var_from_path_or_env("SELFHOST", "true")
  |> String.to_existing_atom()

custom_script_name =
  config_dir
  |> get_var_from_path_or_env("CUSTOM_SCRIPT_NAME", "script")

{site_limit, ""} =
  config_dir
  |> get_var_from_path_or_env("SITE_LIMIT", "50")
  |> Integer.parse()

site_limit_exempt =
  config_dir
  |> get_var_from_path_or_env("SITE_LIMIT_EXEMPT", "")
  |> String.split(",")
  |> Enum.map(&String.trim/1)

disable_cron =
  config_dir
  |> get_var_from_path_or_env("DISABLE_CRON", "false")
  |> String.to_existing_atom()

{user_agent_cache_limit, ""} =
  config_dir
  |> get_var_from_path_or_env("USER_AGENT_CACHE_LIMIT", "1000")
  |> Integer.parse()

user_agent_cache_stats =
  config_dir
  |> get_var_from_path_or_env("USER_AGENT_CACHE_STATS", "false")
  |> String.to_existing_atom()

config :plausible,
  admin_user: admin_user,
  admin_email: admin_email,
  admin_pwd: admin_pwd,
  environment: env,
  mailer_email: mailer_email,
  super_admin_user_ids: super_admin_user_ids,
  site_limit: site_limit,
  site_limit_exempt: site_limit_exempt,
  is_selfhost: is_selfhost,
  custom_script_name: custom_script_name,
  domain_blacklist: domain_blacklist

config :plausible, :selfhost,
  disable_authentication: disable_auth,
  enable_email_verification: enable_email_verification,
  disable_registration: if(!disable_auth, do: disable_registration, else: false)

config :plausible, PlausibleWeb.Endpoint,
  url: [scheme: base_url.scheme, host: base_url.host, path: base_url.path, port: base_url.port],
  http: [port: port, ip: listen_ip, transport_options: [max_connections: :infinity]],
  secret_key_base: secret_key_base

maybe_ipv6 = if System.get_env("ECTO_IPV6"), do: [:inet6], else: []

if is_nil(db_socket_dir) do
  config :plausible, Plausible.Repo,
    url: db_url,
    socket_options: maybe_ipv6
else
  config :plausible, Plausible.Repo,
    socket_dir: db_socket_dir,
    database: get_var_from_path_or_env(config_dir, "DATABASE_NAME", "plausible")
end

config :sentry,
  dsn: sentry_dsn,
  environment_name: env,
  included_environments: ["prod", "staging"],
  release: app_version,
  tags: %{app_version: app_version},
  enable_source_code_context: true,
  root_source_code_path: [File.cwd!()]

config :plausible, :paddle,
  vendor_auth_code: paddle_auth_code,
  vendor_id: paddle_vendor_id

config :plausible, :google,
  client_id: google_cid,
  client_secret: google_secret

config :plausible, :slack, webhook: slack_hook_url

config :plausible, Plausible.ClickhouseRepo,
  loggers: [Ecto.LogEntry],
  queue_target: 500,
  queue_interval: 2000,
  url: ch_db_url,
  flush_interval_ms: ch_flush_interval_ms,
  max_buffer_size: ch_max_buffer_size

case mailer_adapter do
  "Bamboo.PostmarkAdapter" ->
    config :plausible, Plausible.Mailer,
      adapter: :"Elixir.#{mailer_adapter}",
      request_options: [recv_timeout: 10_000],
      api_key: get_var_from_path_or_env(config_dir, "POSTMARK_API_KEY")

  "Bamboo.SMTPAdapter" ->
    config :plausible, Plausible.Mailer,
      adapter: :"Elixir.#{mailer_adapter}",
      server: get_var_from_path_or_env(config_dir, "SMTP_HOST_ADDR", "mail"),
      hostname: base_url.host,
      port: get_var_from_path_or_env(config_dir, "SMTP_HOST_PORT", "25"),
      username: get_var_from_path_or_env(config_dir, "SMTP_USER_NAME"),
      password: get_var_from_path_or_env(config_dir, "SMTP_USER_PWD"),
      tls: :if_available,
      allowed_tls_versions: [:tlsv1, :"tlsv1.1", :"tlsv1.2"],
      ssl: get_var_from_path_or_env(config_dir, "SMTP_HOST_SSL_ENABLED") || false,
      retries: get_var_from_path_or_env(config_dir, "SMTP_RETRIES") || 2,
      no_mx_lookups: get_var_from_path_or_env(config_dir, "SMTP_MX_LOOKUPS_ENABLED") || true

  "Bamboo.LocalAdapter" ->
    config :plausible, Plausible.Mailer, adapter: Bamboo.LocalAdapter

  "Bamboo.TestAdapter" ->
    config :plausible, Plausible.Mailer, adapter: Bamboo.TestAdapter

  _ ->
    raise "Unknown mailer_adapter; expected SMTPAdapter or PostmarkAdapter"
end

config :plausible, PlausibleWeb.Firewall,
  blocklist:
    get_var_from_path_or_env(config_dir, "IP_BLOCKLIST", "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)

if config_env() == :prod && !disable_cron do
  base_cron = [
    # Daily at midnight
    {"0 0 * * *", Plausible.Workers.RotateSalts},
    #  hourly
    {"0 * * * *", Plausible.Workers.ScheduleEmailReports},
    # hourly
    {"0 * * * *", Plausible.Workers.SendSiteSetupEmails},
    # Daily at midday
    {"0 12 * * *", Plausible.Workers.SendCheckStatsEmails},
    # Every 15 minutes
    {"*/15 * * * *", Plausible.Workers.SpikeNotifier},
    # Every day at midnight
    {"0 0 * * *", Plausible.Workers.CleanEmailVerificationCodes},
    # Every day at 1am
    {"0 1 * * *", Plausible.Workers.CleanInvitations}
  ]

  extra_cron = [
    # Daily at midday
    {"0 12 * * *", Plausible.Workers.SendTrialNotifications},
    # Daily at 14
    {"0 14 * * *", Plausible.Workers.CheckUsage},
    # Daily at 15
    {"0 15 * * *", Plausible.Workers.NotifyAnnualRenewal},
    # Every midnight
    {"0 0 * * *", Plausible.Workers.LockSites}
  ]

  base_queues = [
    rotate_salts: 1,
    schedule_email_reports: 1,
    send_email_reports: 1,
    spike_notifications: 1,
    check_stats_emails: 1,
    site_setup_emails: 1,
    clean_email_verification_codes: 1,
    clean_invitations: 1,
    google_analytics_imports: 1
  ]

  extra_queues = [
    provision_ssl_certificates: 1,
    trial_notification_emails: 1,
    check_usage: 1,
    notify_annual_renewal: 1,
    lock_sites: 1
  ]

  # Keep 30 days history
  config :plausible, Oban,
    repo: Plausible.Repo,
    plugins: [{Oban.Plugins.Pruner, max_age: 2_592_000}],
    queues: if(is_selfhost, do: base_queues, else: base_queues ++ extra_queues),
    crontab: if(is_selfhost, do: base_cron, else: base_cron ++ extra_cron)
else
  config :plausible, Oban,
    repo: Plausible.Repo,
    queues: [google_analytics_imports: 1],
    plugins: false
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

config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4, cleanup_interval_ms: 60_000 * 10]}

config :kaffy,
  otp_app: :plausible,
  ecto_repo: Plausible.Repo,
  router: PlausibleWeb.Router,
  admin_title: "Plausible Admin",
  resources: [
    auth: [
      resources: [
        user: [schema: Plausible.Auth.User, admin: Plausible.Auth.UserAdmin],
        api_key: [schema: Plausible.Auth.ApiKey, admin: Plausible.Auth.ApiKeyAdmin]
      ]
    ],
    sites: [
      resources: [
        site: [schema: Plausible.Site, admin: Plausible.SiteAdmin]
      ]
    ],
    billing: [
      resources: [
        enterprise_plan: [
          schema: Plausible.Billing.EnterprisePlan,
          admin: Plausible.Billing.EnterprisePlanAdmin
        ]
      ]
    ]
  ]

if config_env() != :test do
  config :geolix,
    databases: [
      %{
        id: :geolocation,
        adapter: Geolix.Adapter.MMDB2,
        source: ip_geolocation_db,
        result_as: :raw
      }
    ]
end

if geonames_source_file do
  config :location, :geonames_source_file, geonames_source_file
end

config :logger,
  level: log_level,
  backends: [:console]

config :logger, Sentry.LoggerBackend,
  capture_log_messages: true,
  level: :error,
  excluded_domains: []

# if honeycomb_api_key && honeycomb_dataset do
#   config :opentelemetry, :processors,
#     otel_batch_processor: %{
#       exporter:
#         {:opentelemetry_exporter,
#          %{
#            endpoints: ['https://api.honeycomb.io:443'],
#            headers: [
#              {"x-honeycomb-team", honeycomb_api_key},
#              {"x-honeycomb-dataset", honeycomb_dataset}
#            ]
#          }}
#     }
# end

config :tzdata,
       :data_dir,
       get_var_from_path_or_env(config_dir, "STORAGE_DIR", Application.app_dir(:tzdata, "priv"))
