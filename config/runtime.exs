import Config
import Plausible.ConfigHelpers
require Logger

if config_env() in [:dev, :test] do
  Envy.load(["config/.env.#{config_env()}"])
end

if config_env() == :small_dev do
  Envy.load(["config/.env.dev"])
end

if config_env() == :small_test do
  Envy.load(["config/.env.test"])
end

config_dir = System.get_env("CONFIG_DIR", "/run/secrets")
storage_dir = get_var_from_path_or_env(config_dir, "STORAGE_DIR", System.tmp_dir!())

log_format =
  get_var_from_path_or_env(config_dir, "LOG_FORMAT", "standard")

log_level =
  config_dir
  |> get_var_from_path_or_env("LOG_LEVEL", "warning")
  |> String.to_existing_atom()

config :logger,
  level: log_level,
  backends: [:console]

config :logger, Sentry.LoggerBackend,
  capture_log_messages: true,
  level: :error

case String.downcase(log_format) do
  "standard" ->
    config :logger, :console,
      format: "$time $metadata[$level] $message\n",
      metadata: [:request_id]

  "json" ->
    config :logger, :console,
      format: {ExJsonLogger, :format},
      metadata: [
        :request_id
      ]
end

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

super_admin_user_ids =
  get_var_from_path_or_env(config_dir, "ADMIN_USER_IDS", "")
  |> String.split(",")
  |> Enum.map(fn id -> Integer.parse(id) end)
  |> Enum.map(fn
    {int, ""} -> int
    _ -> nil
  end)
  |> Enum.filter(& &1)

env = get_var_from_path_or_env(config_dir, "ENVIRONMENT", "prod")
mailer_adapter = get_var_from_path_or_env(config_dir, "MAILER_ADAPTER", "Bamboo.SMTPAdapter")
mailer_email = get_var_from_path_or_env(config_dir, "MAILER_EMAIL", "hello@plausible.local")

mailer_email =
  if mailer_name = get_var_from_path_or_env(config_dir, "MAILER_NAME") do
    {mailer_name, mailer_email}
  else
    mailer_email
  end

app_version = get_var_from_path_or_env(config_dir, "APP_VERSION", "0.0.1")

ch_db_url =
  get_var_from_path_or_env(
    config_dir,
    "CLICKHOUSE_DATABASE_URL",
    "http://plausible_events_db:8123/plausible_events_db"
  )

{ingest_pool_size, ""} =
  get_var_from_path_or_env(
    config_dir,
    "CLICKHOUSE_INGEST_POOL_SIZE",
    "5"
  )
  |> Integer.parse()

{ch_flush_interval_ms, ""} =
  config_dir
  |> get_var_from_path_or_env("CLICKHOUSE_FLUSH_INTERVAL_MS", "5000")
  |> Integer.parse()

if get_var_from_path_or_env(config_dir, "CLICKHOUSE_MAX_BUFFER_SIZE") do
  Logger.warning(
    "CLICKHOUSE_MAX_BUFFER_SIZE is deprecated, please use CLICKHOUSE_MAX_BUFFER_SIZE_BYTES instead"
  )
end

{ch_max_buffer_size, ""} =
  config_dir
  |> get_var_from_path_or_env("CLICKHOUSE_MAX_BUFFER_SIZE_BYTES", "100000")
  |> Integer.parse()

# Can be generated  with `Base.encode64(:crypto.strong_rand_bytes(32))` from
# iex shell or `openssl rand -base64 32` from command line.
totp_vault_key = get_var_from_path_or_env(config_dir, "TOTP_VAULT_KEY", nil)

case totp_vault_key do
  nil ->
    raise "TOTP_VAULT_KEY configuration option is required. See https://plausible.io/docs/self-hosting-configuration#server"

  key ->
    if byte_size(Base.decode64!(key)) != 32 do
      raise "TOTP_VAULT_KEY must exactly 32 bytes long. See https://plausible.io/docs/self-hosting-configuration#server"
    end
end

### Mandatory params End

build_metadata_raw = get_var_from_path_or_env(config_dir, "BUILD_METADATA", "{}")

build_metadata =
  case Jason.decode(build_metadata_raw) do
    {:ok, build_metadata} ->
      build_metadata

    {:error, error} ->
      error = Exception.format(:error, error)

      Logger.warning("""
      failed to parse $BUILD_METADATA: #{error}

          $BUILD_METADATA is set to #{build_metadata_raw}\
      """)

      Logger.warning("falling back to empty build metadata, as if $BUILD_METADATA was set to {}")

      _fallback = %{}
  end

runtime_metadata = [
  version: get_in(build_metadata, ["labels", "org.opencontainers.image.version"]),
  commit: get_in(build_metadata, ["labels", "org.opencontainers.image.revision"]),
  created: get_in(build_metadata, ["labels", "org.opencontainers.image.created"]),
  tags: get_in(build_metadata, ["tags"])
]

config :plausible, :runtime_metadata, runtime_metadata

config :plausible, Plausible.Auth.TOTP, vault_key: totp_vault_key

sentry_dsn = get_var_from_path_or_env(config_dir, "SENTRY_DSN")
honeycomb_api_key = get_var_from_path_or_env(config_dir, "HONEYCOMB_API_KEY")
honeycomb_dataset = get_var_from_path_or_env(config_dir, "HONEYCOMB_DATASET")
paddle_auth_code = get_var_from_path_or_env(config_dir, "PADDLE_VENDOR_AUTH_CODE")
paddle_vendor_id = get_var_from_path_or_env(config_dir, "PADDLE_VENDOR_ID")
google_cid = get_var_from_path_or_env(config_dir, "GOOGLE_CLIENT_ID")
google_secret = get_var_from_path_or_env(config_dir, "GOOGLE_CLIENT_SECRET")
postmark_api_key = get_var_from_path_or_env(config_dir, "POSTMARK_API_KEY")

{otel_sampler_ratio, ""} =
  config_dir
  |> get_var_from_path_or_env("OTEL_SAMPLER_RATIO", "0.5")
  |> Float.parse()

cron_enabled =
  config_dir
  |> get_var_from_path_or_env("CRON_ENABLED", "false")
  |> String.to_existing_atom()

geolite2_country_db =
  get_var_from_path_or_env(
    config_dir,
    "GEOLITE2_COUNTRY_DB",
    Application.app_dir(:plausible, "/priv/geodb/dbip-country.mmdb.gz")
  )

ip_geolocation_db = get_var_from_path_or_env(config_dir, "IP_GEOLOCATION_DB", geolite2_country_db)
geonames_source_file = get_var_from_path_or_env(config_dir, "GEONAMES_SOURCE_FILE")
maxmind_license_key = get_var_from_path_or_env(config_dir, "MAXMIND_LICENSE_KEY")
maxmind_edition = get_var_from_path_or_env(config_dir, "MAXMIND_EDITION", "GeoLite2-City")
maxmind_database_cache_file = get_var_from_path_or_env(config_dir, "MAXMIND_DATABASE_CACHE_FILE")

if System.get_env("DISABLE_AUTH") do
  Logger.warning("DISABLE_AUTH env var is no longer supported")
end

enable_email_verification =
  config_dir
  |> get_var_from_path_or_env("ENABLE_EMAIL_VERIFICATION", "false")
  |> String.to_existing_atom()

is_selfhost =
  config_dir
  |> get_var_from_path_or_env("SELFHOST", "true")
  |> String.to_existing_atom()

# by default, registration is disabled in self-hosted setups
disable_registration_default = to_string(is_selfhost)

disable_registration =
  config_dir
  |> get_var_from_path_or_env("DISABLE_REGISTRATION", disable_registration_default)
  |> String.to_existing_atom()

if disable_registration not in [true, false, :invite_only] do
  raise "DISABLE_REGISTRATION must be one of `true`, `false`, or `invite_only`. See https://plausible.io/docs/self-hosting-configuration#server"
end

hcaptcha_sitekey = get_var_from_path_or_env(config_dir, "HCAPTCHA_SITEKEY")
hcaptcha_secret = get_var_from_path_or_env(config_dir, "HCAPTCHA_SECRET")

custom_script_name =
  config_dir
  |> get_var_from_path_or_env("CUSTOM_SCRIPT_NAME", "script")

disable_cron =
  config_dir
  |> get_var_from_path_or_env("DISABLE_CRON", "false")
  |> String.to_existing_atom()

log_failed_login_attempts =
  config_dir
  |> get_var_from_path_or_env("LOG_FAILED_LOGIN_ATTEMPTS", "false")
  |> String.to_existing_atom()

websocket_url = get_var_from_path_or_env(config_dir, "WEBSOCKET_URL", "")

if byte_size(websocket_url) > 0 and
     not String.ends_with?(URI.new!(websocket_url).host, base_url.host) do
  raise """
  Cross-domain websocket authentication is not supported for this server.

  WEBSOCKET_URL=#{websocket_url} - host must be: '#{base_url.host}',
  because BASE_URL=#{base_url}.
  """
end

secure_cookie =
  config_dir
  |> get_var_from_path_or_env("SECURE_COOKIE", if(is_selfhost, do: "false", else: "true"))
  |> String.to_existing_atom()

config :plausible,
  environment: env,
  mailer_email: mailer_email,
  super_admin_user_ids: super_admin_user_ids,
  is_selfhost: is_selfhost,
  custom_script_name: custom_script_name,
  log_failed_login_attempts: log_failed_login_attempts

config :plausible, :selfhost,
  enable_email_verification: enable_email_verification,
  disable_registration: disable_registration

config :plausible, PlausibleWeb.Endpoint,
  url: [scheme: base_url.scheme, host: base_url.host, path: base_url.path, port: base_url.port],
  http: [
    port: port,
    ip: listen_ip,
    transport_options: [max_connections: :infinity],
    protocol_options: [max_request_line_length: 8192, max_header_value_length: 8192]
  ],
  secret_key_base: secret_key_base,
  websocket_url: websocket_url,
  secure_cookie: secure_cookie

maybe_ipv6 = if System.get_env("ECTO_IPV6"), do: [:inet6], else: []

db_cacertfile = get_var_from_path_or_env(config_dir, "DATABASE_CACERTFILE", CAStore.file_path())

if is_nil(db_socket_dir) do
  config :plausible, Plausible.Repo,
    url: db_url,
    socket_options: maybe_ipv6,
    ssl_opts: [
      cacertfile: db_cacertfile,
      verify: :verify_peer,
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ]
else
  config :plausible, Plausible.Repo,
    socket_dir: db_socket_dir,
    database: get_var_from_path_or_env(config_dir, "DATABASE_NAME", "plausible")
end

included_environments = if sentry_dsn, do: ["prod", "staging", "dev"], else: []
sentry_app_version = runtime_metadata[:version] || app_version

config :sentry,
  dsn: sentry_dsn,
  environment_name: env,
  included_environments: included_environments,
  release: sentry_app_version,
  tags: %{app_version: sentry_app_version},
  enable_source_code_context: true,
  root_source_code_path: [File.cwd!()],
  client: Plausible.Sentry.Client,
  send_max_attempts: 1,
  filter: Plausible.SentryFilter,
  before_send_event: {Plausible.SentryFilter, :before_send}

config :plausible, :paddle,
  vendor_auth_code: paddle_auth_code,
  vendor_id: paddle_vendor_id

config :plausible, :google,
  client_id: google_cid,
  client_secret: google_secret,
  api_url: "https://www.googleapis.com",
  reporting_api_url: "https://analyticsreporting.googleapis.com"

config :plausible, :imported,
  max_buffer_size: get_int_from_path_or_env(config_dir, "IMPORTED_MAX_BUFFER_SIZE", 10_000)

maybe_ch_ipv6 =
  get_var_from_path_or_env(config_dir, "ECTO_CH_IPV6", "false")
  |> String.to_existing_atom()

ch_cacertfile = get_var_from_path_or_env(config_dir, "CLICKHOUSE_CACERTFILE")

ch_transport_opts = [
  keepalive: true,
  show_econnreset: true,
  inet6: maybe_ch_ipv6
]

ch_transport_opts =
  if ch_cacertfile do
    ch_transport_opts ++ [cacertfile: ch_cacertfile]
  else
    ch_transport_opts
  end

config :plausible, Plausible.ClickhouseRepo,
  queue_target: 500,
  queue_interval: 2000,
  url: ch_db_url,
  transport_opts: ch_transport_opts,
  settings: [
    readonly: 1,
    join_algorithm: "direct,parallel_hash"
  ]

config :plausible, Plausible.IngestRepo,
  queue_target: 500,
  queue_interval: 2000,
  url: ch_db_url,
  transport_opts: ch_transport_opts,
  flush_interval_ms: ch_flush_interval_ms,
  max_buffer_size: ch_max_buffer_size,
  pool_size: ingest_pool_size,
  settings: [
    materialized_views_ignore_errors: 1
  ]

config :plausible, Plausible.AsyncInsertRepo,
  queue_target: 500,
  queue_interval: 2000,
  url: ch_db_url,
  transport_opts: ch_transport_opts,
  pool_size: 1,
  settings: [
    async_insert: 1,
    wait_for_async_insert: 0,
    materialized_views_ignore_errors: 1
  ]

config :plausible, Plausible.ImportDeletionRepo,
  queue_target: 500,
  queue_interval: 2000,
  url: ch_db_url,
  transport_opts: ch_transport_opts,
  pool_size: 1

config :ex_money,
  open_exchange_rates_app_id: get_var_from_path_or_env(config_dir, "OPEN_EXCHANGE_RATES_APP_ID"),
  retrieve_every: :timer.hours(24)

case mailer_adapter do
  "Bamboo.PostmarkAdapter" ->
    config :plausible, Plausible.Mailer,
      adapter: Bamboo.PostmarkAdapter,
      request_options: [recv_timeout: 10_000],
      api_key: get_var_from_path_or_env(config_dir, "POSTMARK_API_KEY")

  "Bamboo.MailgunAdapter" ->
    config :plausible, Plausible.Mailer,
      adapter: Bamboo.MailgunAdapter,
      hackney_opts: [recv_timeout: :timer.seconds(10)],
      api_key: get_var_from_path_or_env(config_dir, "MAILGUN_API_KEY"),
      domain: get_var_from_path_or_env(config_dir, "MAILGUN_DOMAIN")

    if mailgun_base_uri = get_var_from_path_or_env(config_dir, "MAILGUN_BASE_URI") do
      config :plausible, Plausible.Mailer, base_uri: mailgun_base_uri
    end

  "Bamboo.MandrillAdapter" ->
    config :plausible, Plausible.Mailer,
      adapter: Bamboo.MandrillAdapter,
      hackney_opts: [recv_timeout: :timer.seconds(10)],
      api_key: get_var_from_path_or_env(config_dir, "MANDRILL_API_KEY")

  "Bamboo.SendGridAdapter" ->
    config :plausible, Plausible.Mailer,
      adapter: Bamboo.SendGridAdapter,
      hackney_opts: [recv_timeout: :timer.seconds(10)],
      api_key: get_var_from_path_or_env(config_dir, "SENDGRID_API_KEY")

  "Bamboo.SMTPAdapter" ->
    config :plausible, Plausible.Mailer,
      adapter: Bamboo.SMTPAdapter,
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
    raise ArgumentError, """
    Unknown mailer_adapter: #{inspect(mailer_adapter)}

    Please see https://hexdocs.pm/bamboo/readme.html#available-adapters
    for the list of available adapters that ship with Bamboo
    """
end

base_cron = [
  # Daily at midnight
  {"0 0 * * *", Plausible.Workers.RotateSalts},
  # hourly
  {"0 * * * *", Plausible.Workers.ScheduleEmailReports},
  # hourly
  {"0 * * * *", Plausible.Workers.SendSiteSetupEmails},
  # Daily at midday
  {"0 12 * * *", Plausible.Workers.SendCheckStatsEmails},
  # Every 15 minutes
  {"*/15 * * * *", Plausible.Workers.SpikeNotifier},
  # Every day at 1am
  {"0 1 * * *", Plausible.Workers.CleanInvitations},
  # Every 2 hours
  {"0 */2 * * *", Plausible.Workers.ExpireDomainChangeTransitions}
]

cloud_cron = [
  # Daily at midday
  {"0 12 * * *", Plausible.Workers.SendTrialNotifications},
  # Daily at 14
  {"0 14 * * *", Plausible.Workers.CheckUsage},
  # Daily at 15
  {"0 15 * * *", Plausible.Workers.NotifyAnnualRenewal},
  # Every midnight
  {"0 0 * * *", Plausible.Workers.LockSites},
  # Daily at 8
  {"0 8 * * *", Plausible.Workers.AcceptTrafficUntil}
]

crontab = if(is_selfhost, do: base_cron, else: base_cron ++ cloud_cron)

base_queues = [
  rotate_salts: 1,
  schedule_email_reports: 1,
  send_email_reports: 1,
  spike_notifications: 1,
  check_stats_emails: 1,
  site_setup_emails: 1,
  clean_invitations: 1,
  analytics_imports: 1,
  domain_change_transition: 1,
  check_accept_traffic_until: 1
]

cloud_queues = [
  trial_notification_emails: 1,
  check_usage: 1,
  notify_annual_renewal: 1,
  lock_sites: 1
]

queues = if(is_selfhost, do: base_queues, else: base_queues ++ cloud_queues)
cron_enabled = !disable_cron

thirty_days_in_seconds = 60 * 60 * 24 * 30

cond do
  config_env() == :prod ->
    config :plausible, Oban,
      repo: Plausible.Repo,
      plugins: [
        # Keep 30 days history
        {Oban.Plugins.Pruner, max_age: thirty_days_in_seconds},
        {Oban.Plugins.Cron, crontab: if(cron_enabled, do: crontab, else: [])},
        # Rescue orphaned jobs after 2 hours
        {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(120)}
      ],
      queues: if(cron_enabled, do: queues, else: []),
      peer: if(cron_enabled, do: Oban.Peers.Postgres, else: false)

  true ->
    config :plausible, Oban,
      repo: Plausible.Repo,
      queues: queues,
      plugins: false
end

config :plausible, :hcaptcha,
  sitekey: hcaptcha_sitekey,
  secret: hcaptcha_secret

nolt_sso_secret = get_var_from_path_or_env(config_dir, "NOLT_SSO_SECRET")
config :joken, default_signer: nolt_sso_secret

config :plausible, Plausible.Sentry.Client,
  finch_request_opts: [
    pool_timeout: get_int_from_path_or_env(config_dir, "SENTRY_FINCH_POOL_TIMEOUT", 5000),
    receive_timeout: get_int_from_path_or_env(config_dir, "SENTRY_FINCH_RECEIVE_TIMEOUT", 15000)
  ]

config :ref_inspector,
  init: {Plausible.Release, :configure_ref_inspector}

config :ua_inspector,
  init: {Plausible.Release, :configure_ua_inspector}

if config_env() in [:dev, :staging, :prod] do
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
end

geo_opts =
  cond do
    maxmind_license_key ->
      [
        license_key: maxmind_license_key,
        edition: maxmind_edition,
        database_cache_file: maxmind_database_cache_file,
        async: true
      ]

    ip_geolocation_db ->
      [path: ip_geolocation_db]

    true ->
      raise """
      Missing geolocation database configuration.

      Please set the IP_GEOLOCATION_DB environment value to the location of
      your IP geolocation .mmdb file:

          IP_GEOLOCATION_DB=/etc/plausible/dbip-city.mmdb

      Or authenticate with MaxMind by
      configuring MAXMIND_LICENSE_KEY and (optionally) MAXMIND_EDITION environment
      variables:

          MAXMIND_LICENSE_KEY=LNpsJCCKPis6XvBP
          MAXMIND_EDITION=GeoLite2-City # this is the default edition

      """
  end

config :plausible, Plausible.Geo, geo_opts

if geonames_source_file do
  config :location, :geonames_source_file, geonames_source_file
end

if honeycomb_api_key && honeycomb_dataset do
  config :opentelemetry,
    resource: Plausible.OpenTelemetry.resource_attributes(runtime_metadata),
    sampler: {Plausible.OpenTelemetry.Sampler, %{ratio: otel_sampler_ratio}},
    span_processor: :batch,
    traces_exporter: :otlp

  config :opentelemetry_exporter,
    otlp_protocol: :grpc,
    otlp_endpoint: "https://api.honeycomb.io:443",
    otlp_headers: [
      {"x-honeycomb-team", honeycomb_api_key},
      {"x-honeycomb-dataset", honeycomb_dataset}
    ]
else
  config :opentelemetry,
    sampler: :always_off,
    traces_exporter: :none
end

config :tzdata, :data_dir, Path.join(storage_dir, "plausible_tzdata_data")

promex_disabled? =
  config_dir
  |> get_var_from_path_or_env("PROMEX_DISABLED", "true")
  |> String.to_existing_atom()

config :plausible, Plausible.PromEx,
  disabled: promex_disabled?,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: :disabled,
  metrics_server: :disabled

if not is_selfhost do
  site_default_ingest_threshold =
    case System.get_env("SITE_DEFAULT_INGEST_THRESHOLD") do
      threshold when byte_size(threshold) > 0 ->
        {value, ""} = Integer.parse(threshold)
        value

      _ ->
        nil
    end

  config :plausible, Plausible.Site, default_ingest_threshold: site_default_ingest_threshold
end
