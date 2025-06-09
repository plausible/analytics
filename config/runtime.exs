import Config
import Plausible.ConfigHelpers
require Logger

if config_env() in [:dev, :test, :load] do
  Envy.load(["config/.env.#{config_env()}"])
end

if config_env() == :ce_dev do
  Envy.load(["config/.env.dev"])
end

if config_env() == :ce_test do
  Envy.load(["config/.env.test"])
end

config_dir = System.get_env("CONFIG_DIR", "/run/secrets")

log_format =
  get_var_from_path_or_env(config_dir, "LOG_FORMAT", "standard")

default_log_level = if config_env() == :ce, do: "notice", else: "warning"

log_level =
  config_dir
  |> get_var_from_path_or_env("LOG_LEVEL", default_log_level)
  |> String.to_existing_atom()

config :logger, level: log_level
config :logger, :default_formatter, metadata: [:request_id]

config :logger, Sentry.LoggerBackend,
  capture_log_messages: true,
  level: :error

case String.downcase(log_format) do
  "standard" ->
    config :logger, :default_formatter, format: "$time $metadata[$level] $message\n"

  "json" ->
    config :logger, :default_formatter, format: {ExJsonLogger, :format}
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
http_port =
  get_int_from_path_or_env(config_dir, "HTTP_PORT") ||
    get_int_from_path_or_env(config_dir, "PORT", 8000)

https_port = get_int_from_path_or_env(config_dir, "HTTPS_PORT")

base_url = get_var_from_path_or_env(config_dir, "BASE_URL")

if !base_url do
  raise "BASE_URL configuration option is required. See https://github.com/plausible/community-edition/wiki/configuration#base_url"
end

base_url = URI.parse(base_url)

if base_url.scheme not in ["http", "https"] do
  raise "BASE_URL must start with `http` or `https`. Currently configured as `#{System.get_env("BASE_URL")}`"
end

secret_key_base = get_var_from_path_or_env(config_dir, "SECRET_KEY_BASE", nil)

case secret_key_base do
  nil ->
    raise "SECRET_KEY_BASE configuration option is required. See https://github.com/plausible/community-edition/wiki/configuration#secret_key_base"

  key when byte_size(key) < 32 ->
    raise "SECRET_KEY_BASE must be at least 32 bytes long. See https://github.com/plausible/community-edition/wiki/configuration#secret_key_base"

  _ ->
    nil
end

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
mailer_adapter = get_var_from_path_or_env(config_dir, "MAILER_ADAPTER", "Bamboo.Mua")
mailer_email = get_var_from_path_or_env(config_dir, "MAILER_EMAIL", "plausible@#{base_url.host}")

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
totp_vault_key =
  if totp_vault_key_base64 = get_var_from_path_or_env(config_dir, "TOTP_VAULT_KEY") do
    case Base.decode64(totp_vault_key_base64) do
      {:ok, totp_vault_key} ->
        if byte_size(totp_vault_key) == 32 do
          totp_vault_key
        else
          raise ArgumentError, """
          TOTP_VAULT_KEY must be Base64 encoded 32 bytes, e.g. `openssl rand -base64 32`.
          Got Base64 encoded #{byte_size(totp_vault_key)} bytes.
          More info: https://github.com/plausible/community-edition/wiki/configuration#totp_vault_key
          """
        end

      :error ->
        raise ArgumentError, """
        TOTP_VAULT_KEY must be Base64 encoded 32 bytes, e.g. `openssl rand -base64 32`
        More info: https://github.com/plausible/community-edition/wiki/configuration#totp_vault_key
        """
    end
  else
    Plug.Crypto.KeyGenerator.generate(secret_key_base, "totp", length: 32, iterations: 100_000)
  end

config :plausible, Plausible.Auth.TOTP, vault_key: totp_vault_key

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

app_host = get_var_from_path_or_env(config_dir, "APP_HOST")

runtime_metadata = [
  version: get_in(build_metadata, ["labels", "org.opencontainers.image.version"]),
  commit: get_in(build_metadata, ["labels", "org.opencontainers.image.revision"]),
  created: get_in(build_metadata, ["labels", "org.opencontainers.image.created"]),
  tags: get_in(build_metadata, ["tags"]),
  app_host: app_host
]

config :plausible, :runtime_metadata, runtime_metadata

sentry_dsn = get_var_from_path_or_env(config_dir, "SENTRY_DSN")
honeycomb_api_key = get_var_from_path_or_env(config_dir, "HONEYCOMB_API_KEY")
honeycomb_dataset = get_var_from_path_or_env(config_dir, "HONEYCOMB_DATASET")
paddle_auth_code = get_var_from_path_or_env(config_dir, "PADDLE_VENDOR_AUTH_CODE")
paddle_vendor_id = get_var_from_path_or_env(config_dir, "PADDLE_VENDOR_ID")
google_cid = get_var_from_path_or_env(config_dir, "GOOGLE_CLIENT_ID")
google_secret = get_var_from_path_or_env(config_dir, "GOOGLE_CLIENT_SECRET")
postmark_api_key = get_var_from_path_or_env(config_dir, "POSTMARK_API_KEY")
help_scout_app_id = get_var_from_path_or_env(config_dir, "HELP_SCOUT_APP_ID")
help_scout_app_secret = get_var_from_path_or_env(config_dir, "HELP_SCOUT_APP_SECRET")
help_scout_signature_key = get_var_from_path_or_env(config_dir, "HELP_SCOUT_SIGNATURE_KEY")
help_scout_vault_key = get_var_from_path_or_env(config_dir, "HELP_SCOUT_VAULT_KEY")

{otel_sampler_ratio, ""} =
  config_dir
  |> get_var_from_path_or_env("OTEL_SAMPLER_RATIO", "0.5")
  |> Float.parse()

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
data_dir = get_var_from_path_or_env(config_dir, "DATA_DIR")
persistent_cache_dir = get_var_from_path_or_env(config_dir, "PERSISTENT_CACHE_DIR")

# DEFAULT_DATA_DIR comes from the container image, please see our Dockerfile
data_dir = data_dir || persistent_cache_dir || System.get_env("DEFAULT_DATA_DIR")
persistent_cache_dir = persistent_cache_dir || data_dir

session_transfer_dir =
  if get_bool_from_path_or_env(config_dir, "ENABLE_SESSION_TRANSFER", config_env() == :prod) do
    if persistent_cache_dir do
      Path.join(persistent_cache_dir, "sessions")
    end
  end

enable_email_verification =
  get_bool_from_path_or_env(config_dir, "ENABLE_EMAIL_VERIFICATION", false)

is_selfhost = get_bool_from_path_or_env(config_dir, "SELFHOST", true)

# by default, only registration from invites is enabled in CE
disable_registration_default =
  if config_env() == :ce do
    "invite_only"
  else
    "false"
  end

disable_registration =
  config_dir
  |> get_var_from_path_or_env("DISABLE_REGISTRATION", disable_registration_default)
  |> String.to_existing_atom()

if disable_registration not in [true, false, :invite_only] do
  raise "DISABLE_REGISTRATION must be one of `true`, `false`, or `invite_only`. See https://github.com/plausible/community-edition/wiki/configuration#disable_registration"
end

hcaptcha_sitekey = get_var_from_path_or_env(config_dir, "HCAPTCHA_SITEKEY")
hcaptcha_secret = get_var_from_path_or_env(config_dir, "HCAPTCHA_SECRET")

custom_script_name =
  config_dir
  |> get_var_from_path_or_env("CUSTOM_SCRIPT_NAME", "script")

disable_cron = get_bool_from_path_or_env(config_dir, "DISABLE_CRON", false)

log_failed_login_attempts =
  get_bool_from_path_or_env(config_dir, "LOG_FAILED_LOGIN_ATTEMPTS", false)

websocket_url = get_var_from_path_or_env(config_dir, "WEBSOCKET_URL", "")

if byte_size(websocket_url) > 0 and
     not String.ends_with?(URI.new!(websocket_url).host, base_url.host) do
  raise """
  Cross-domain websocket authentication is not supported for this server.

  WEBSOCKET_URL=#{websocket_url} - host must be: '#{base_url.host}',
  because BASE_URL=#{base_url}.
  """
end

secure_cookie_default =
  case base_url.scheme do
    "http" -> "false"
    "https" -> "true"
  end

secure_cookie =
  config_dir
  |> get_var_from_path_or_env("SECURE_COOKIE", secure_cookie_default)
  |> String.to_existing_atom()

license_key = get_var_from_path_or_env(config_dir, "LICENSE_KEY", "")

sso_enabled = get_bool_from_path_or_env(config_dir, "SSO_ENABLED", false)

sso_saml_adapter =
  case get_var_from_path_or_env(config_dir, "SSO_SAML_ADAPTER", "fake") do
    "fake" -> PlausibleWeb.SSO.FakeSAMLAdapter
    "real" -> PlausibleWeb.SSO.RealSAMLAdapter
  end

config :plausible,
  environment: env,
  mailer_email: mailer_email,
  super_admin_user_ids: super_admin_user_ids,
  is_selfhost: is_selfhost,
  custom_script_name: custom_script_name,
  log_failed_login_attempts: log_failed_login_attempts,
  license_key: license_key,
  data_dir: data_dir,
  session_transfer_dir: session_transfer_dir,
  sso_enabled: sso_enabled,
  sso_saml_adapter: sso_saml_adapter

config :plausible, :selfhost,
  enable_email_verification: enable_email_verification,
  disable_registration: disable_registration

default_http_opts = [
  transport_options: [max_connections: :infinity],
  protocol_options: [max_request_line_length: 8192, max_header_value_length: 8192]
]

config :plausible, PlausibleWeb.Endpoint,
  url: [scheme: base_url.scheme, host: base_url.host, path: base_url.path, port: base_url.port],
  http: [port: http_port, ip: listen_ip] ++ default_http_opts,
  secret_key_base: secret_key_base,
  websocket_url: websocket_url,
  secure_cookie: secure_cookie

# maybe enable HTTPS in CE
if config_env() in [:ce, :ce_dev, :ce_test] do
  if https_port do
    # the following configuration is based on https://wiki.mozilla.org/Security/Server_Side_TLS#Intermediate_compatibility_.28recommended.29
    # except we enforce the cipher and ecc order and only use ciphers with support
    # for ecdsa certificates since that's what certbot generates by default
    https_opts =
      [
        port: https_port,
        ip: listen_ip,
        transport_options: [socket_opts: [log_level: :warning]],
        versions: [:"tlsv1.2", :"tlsv1.3"],
        honor_cipher_order: true,
        honor_ecc_order: true,
        eccs: [:x25519, :secp256r1, :secp384r1],
        supported_groups: [:x25519, :secp256r1, :secp384r1],
        ciphers: [
          # Mozilla recommended cipher suites (TLS 1.3)
          ~c"TLS_AES_128_GCM_SHA256",
          ~c"TLS_AES_256_GCM_SHA384",
          ~c"TLS_CHACHA20_POLY1305_SHA256",
          # Mozilla recommended cipher suites (TLS 1.2)
          ~c"ECDHE-ECDSA-AES128-GCM-SHA256",
          ~c"ECDHE-ECDSA-AES256-GCM-SHA384",
          ~c"ECDHE-ECDSA-CHACHA20-POLY1305"
        ]
      ]

    https_opts = Config.Reader.merge(default_http_opts, https_opts)
    config :plausible, PlausibleWeb.Endpoint, https: https_opts

    domain = base_url.host

    # do stricter checking in CE prod
    if config_env() == :ce do
      domain_is_ip? =
        case :inet.parse_address(to_charlist(domain)) do
          {:ok, _address} -> true
          _other -> false
        end

      if domain_is_ip? do
        raise ArgumentError, "Cannot generate TLS certificates for IP address #{inspect(domain)}"
      end

      domain_is_local? = domain == "localhost" or not String.contains?(domain, ".")

      if domain_is_local? do
        raise ArgumentError,
              "Cannot generate TLS certificates for local domain #{inspect(domain)}"
      end

      unless http_port == 80 do
        Logger.warning("""
        HTTPS is enabled but the HTTP port is not 80. \
        This will prevent automatic TLS certificate issuance as ACME validates the domain on port 80.\
        """)
      end
    end

    acme_directory_url =
      get_var_from_path_or_env(
        config_dir,
        "ACME_DIRECTORY_URL",
        "https://acme-v02.api.letsencrypt.org/directory"
      )

    db_folder = Path.join(data_dir || System.tmp_dir!(), "site_encrypt")

    email =
      case mailer_email do
        {_, email} -> email
        email when is_binary(email) -> email
      end

    config :plausible, :selfhost,
      site_encrypt: [
        domain: domain,
        email: email,
        db_folder: db_folder,
        directory_url: acme_directory_url
      ]
  end
end

db_maybe_ipv6 =
  if get_bool_from_path_or_env(config_dir, "ECTO_IPV6") do
    if config_env() in [:ce, :ce_dev, :ce_test] do
      Logger.warning(
        "ECTO_IPV6 is no longer necessary as all TCP connections now try IPv6 automatically with IPv4 fallback"
      )
    end

    [:inet6]
  else
    []
  end

db_url =
  get_var_from_path_or_env(
    config_dir,
    "DATABASE_URL",
    "postgres://postgres:postgres@plausible_db:5432/plausible_db"
  )

if db_socket_dir = get_var_from_path_or_env(config_dir, "DATABASE_SOCKET_DIR") do
  Logger.warning("""
  DATABASE_SOCKET_DIR is deprecated, please use DATABASE_URL instead:

      DATABASE_URL=postgresql://postgres:postgres@#{URI.encode_www_form(db_socket_dir)}/plausible_db

  or

      DATABASE_URL=postgresql:///plausible_db?host=#{db_socket_dir}"

  """)
end

db_cacertfile = get_var_from_path_or_env(config_dir, "DATABASE_CACERTFILE")
%URI{host: db_host} = db_uri = URI.parse(db_url)
db_socket_dir? = String.starts_with?(db_host, "%2F") or db_host == ""

if db_socket_dir? do
  [database] = String.split(db_uri.path, "/", trim: true)

  socket_dir =
    if db_host == "" do
      db_host = (db_uri.query || "") |> URI.decode_query() |> Map.get("host")
      db_host || raise ArgumentError, "DATABASE_URL=#{db_url} doesn't include host info"
    else
      URI.decode_www_form(db_host)
    end

  config :plausible, Plausible.Repo,
    socket_dir: socket_dir,
    database: database

  if userinfo = db_uri.userinfo do
    [username, password] = String.split(userinfo, ":")

    config :plausible, Plausible.Repo,
      username: username,
      password: password
  end
else
  config :plausible, Plausible.Repo, url: db_url

  unless Enum.empty?(db_maybe_ipv6) do
    config :plausible, Plausible.Repo, socket_options: db_maybe_ipv6
  end

  db_query = URI.decode_query(db_uri.query || "")
  # https://www.postgresql.org/docs/current/libpq-ssl.html#LIBPQ-SSL-SSLMODE-STATEMENTS
  pg_sslmode = db_query["sslmode"]

  pg_ssl =
    cond do
      db_cacertfile ->
        [cacertfile: db_cacertfile, verify: :verify_peer]

      pg_sslmode == "verify-full" ->
        if pg_sslrootcert = db_query["sslrootcert"] do
          [cacertfile: pg_sslrootcert, verify: :verify_peer]
        else
          raise ArgumentError,
                "PostgreSQL SSL mode `sslmode=#{pg_sslmode}` requires a certificate, set it in `sslrootcert`"
        end

      pg_sslmode == "verify-ca" ->
        [cacerts: :public_key.cacerts_get(), verify: :verify_peer]

      pg_sslmode == "require" ->
        [verify: :verify_none]

      pg_sslmode == "disable" ->
        false

      pg_sslmode ->
        raise ArgumentError,
              "PostgreSQL SSL mode `sslmode=#{pg_sslmode}` is not supported, use `disable`, `require`, `verify-ca` or `verify-full` instead"

      true ->
        # tls is disabled by default, because in self-hosted docker compose postgres is co-located
        false
    end

  config :plausible, Plausible.Repo, ssl: pg_ssl
end

sentry_app_version = runtime_metadata[:version] || app_version

config :sentry,
  dsn: sentry_dsn,
  environment_name: env,
  release: sentry_app_version,
  tags: %{
    app_version: sentry_app_version,
    app_host: app_host
  },
  client: Plausible.Sentry.Client,
  send_max_attempts: 1,
  before_send: {Plausible.SentryFilter, :before_send}

config :plausible, :paddle,
  vendor_auth_code: paddle_auth_code,
  vendor_id: paddle_vendor_id

config :plausible, :google,
  client_id: google_cid,
  client_secret: google_secret,
  api_url: "https://www.googleapis.com",
  reporting_api_url: "https://analyticsreporting.googleapis.com"

config :plausible, Plausible.HelpScout,
  app_id: help_scout_app_id,
  app_secret: help_scout_app_secret,
  signature_key: help_scout_signature_key,
  vault_key: help_scout_vault_key

config :plausible, :imported,
  max_buffer_size: get_int_from_path_or_env(config_dir, "IMPORTED_MAX_BUFFER_SIZE", 10_000)

maybe_ch_ipv6 = get_bool_from_path_or_env(config_dir, "ECTO_CH_IPV6", false)

if maybe_ch_ipv6 && config_env() in [:ce, :ce_dev, :ce_test] do
  Logger.warning(
    "ECTO_CH_IPV6 is no longer necessary as all TCP connections now try IPv6 automatically with IPv4 fallback"
  )
end

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
    join_algorithm: "direct,parallel_hash,hash"
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
  ],
  table_settings: [
    storage_policy: get_var_from_path_or_env(config_dir, "CLICKHOUSE_DEFAULT_STORAGE_POLICY")
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
      ssl: get_bool_from_path_or_env(config_dir, "SMTP_HOST_SSL_ENABLED", false),
      retries: get_var_from_path_or_env(config_dir, "SMTP_RETRIES") || 2,
      no_mx_lookups: get_bool_from_path_or_env(config_dir, "SMTP_MX_LOOKUPS_ENABLED", true)

  "Bamboo.Mua" ->
    config :plausible, Plausible.Mailer, adapter: Bamboo.Mua

    # prevents common problems with Erlang's TLS v1.3
    middlebox_comp_mode =
      get_bool_from_path_or_env(config_dir, "SMTP_MIDDLEBOX_COMP_MODE", false)

    config :plausible, Plausible.Mailer, ssl: [middlebox_comp_mode: middlebox_comp_mode]

    if relay = get_var_from_path_or_env(config_dir, "SMTP_HOST_ADDR") do
      port = get_int_from_path_or_env(config_dir, "SMTP_HOST_PORT", 587)
      ssl_enabled = get_bool_from_path_or_env(config_dir, "SMTP_HOST_SSL_ENABLED")

      protocol =
        cond do
          ssl_enabled -> :ssl
          is_nil(ssl_enabled) and port == 465 -> :ssl
          true -> :tcp
        end

      config :plausible, Plausible.Mailer, protocol: protocol, relay: relay, port: port
    end

    username = get_var_from_path_or_env(config_dir, "SMTP_USER_NAME")
    password = get_var_from_path_or_env(config_dir, "SMTP_USER_PWD")

    cond do
      username && password ->
        config :plausible, Plausible.Mailer, auth: [username: username, password: password]

      username || password ->
        raise ArgumentError, """
        Both SMTP_USER_NAME and SMTP_USER_PWD must be set for SMTP authentication.
        Please provide values for both environment variables.
        """

      _both_nil = true ->
        nil
    end

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
  {"*/15 * * * *", Plausible.Workers.TrafficChangeNotifier},
  # Every day at 1am
  {"0 1 * * *", Plausible.Workers.CleanInvitations},
  # Every 2 hours
  {"30 */2 * * *", Plausible.Workers.CleanUserSessions},
  # Every 2 hours
  {"0 */2 * * *", Plausible.Workers.ExpireDomainChangeTransitions},
  # Daily at midnight
  {"0 0 * * *", Plausible.Workers.LocationsSync}
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
  {"0 8 * * *", Plausible.Workers.AcceptTrafficUntil},
  # First sunday of the month, 4:00 UTC
  {"0 4 1-7 * SUN", Plausible.Workers.ClickhouseCleanSites},
  # Daily at 4:00 UTC
  {"0 4 * * *", Plausible.Workers.SetLegacyTimeOnPageCutoff}
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
  clean_user_sessions: 1,
  analytics_imports: 1,
  analytics_exports: 1,
  notify_exported_analytics: 1,
  domain_change_transition: 1,
  check_accept_traffic_until: 1,
  clickhouse_clean_sites: 1,
  locations_sync: 1
]

cloud_queues = [
  trial_notification_emails: 1,
  check_usage: 1,
  notify_annual_renewal: 1,
  lock_sites: 1,
  legacy_time_on_page_cutoff: 1,
  purge_cdn_cache: 1
]

queues = if(is_selfhost, do: base_queues, else: base_queues ++ cloud_queues)
cron_enabled = !disable_cron

thirty_days_in_seconds = 60 * 60 * 24 * 30

if config_env() in [:prod, :ce, :load] do
  config :plausible, Oban,
    repo: Plausible.Repo,
    plugins: [
      # Keep 30 days history
      {Oban.Plugins.Pruner, max_age: thirty_days_in_seconds},
      {Oban.Plugins.Cron, crontab: if(cron_enabled, do: crontab, else: [])},
      # Rescue orphaned jobs after 2 hours
      {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(120)},
      # Daily at 1am
      {Oban.Plugins.Reindexer, schedule: "0 1 * * *"}
    ],
    queues: if(cron_enabled, do: queues, else: []),
    peer: if(cron_enabled, do: Oban.Peers.Postgres, else: false)
else
  config :plausible, Oban,
    repo: Plausible.Repo,
    queues: queues
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

config :plausible, Plausible.Workers.PurgeCDNCache,
  pullzone_id: get_var_from_path_or_env(config_dir, "BUNNY_PULLZONE_ID"),
  api_key: get_var_from_path_or_env(config_dir, "BUNNY_API_KEY")

config :ref_inspector,
  init: {Plausible.Release, :configure_ref_inspector}

config :ua_inspector,
  init: {Plausible.Release, :configure_ua_inspector}

geo_opts =
  cond do
    maxmind_license_key ->
      [
        license_key: maxmind_license_key,
        edition: maxmind_edition,
        cache_dir: persistent_cache_dir,
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

config :tzdata, :data_dir, Path.join(persistent_cache_dir || System.tmp_dir!(), "tzdata_data")

promex_disabled? = get_bool_from_path_or_env(config_dir, "PROMEX_DISABLED", true)

config :plausible, Plausible.PromEx,
  disabled: promex_disabled?,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: :disabled,
  metrics_server: :disabled

config :plausible, Plausible.Verification.Checks.Installation,
  token: get_var_from_path_or_env(config_dir, "BROWSERLESS_TOKEN", "dummy_token"),
  endpoint: get_var_from_path_or_env(config_dir, "BROWSERLESS_ENDPOINT", "http://0.0.0.0:3000")

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

s3_disabled? = get_bool_from_path_or_env(config_dir, "S3_DISABLED", true)

unless s3_disabled? do
  s3_env = [
    %{
      name: "S3_ACCESS_KEY_ID",
      example: "AKIAIOSFODNN7EXAMPLE"
    },
    %{
      name: "S3_SECRET_ACCESS_KEY",
      example: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    },
    %{
      name: "S3_REGION",
      example: "us-east-1"
    },
    %{
      name: "S3_ENDPOINT",
      example: "https://<ACCOUNT_ID>.r2.cloudflarestorage.com"
    },
    %{
      name: "S3_EXPORTS_BUCKET",
      example: "my-csv-exports-bucket"
    },
    %{
      name: "S3_IMPORTS_BUCKET",
      example: "my-csv-imports-bucket"
    }
  ]

  s3_env =
    Enum.map(s3_env, fn var ->
      Map.put(var, :value, get_var_from_path_or_env(config_dir, var.name))
    end)

  s3_missing_env = Enum.filter(s3_env, &is_nil(&1.value))

  unless s3_missing_env == [] do
    raise ArgumentError, """
    Missing S3 configuration. Please set #{s3_missing_env |> Enum.map(& &1.name) |> Enum.join(", ")} environment variable(s):

    #{s3_missing_env |> Enum.map(fn %{name: name, example: example} -> "\t#{name}=#{example}" end) |> Enum.join("\n")}
    """
  end

  s3_env_value = fn name ->
    s3_env |> Enum.find(&(&1.name == name)) |> Map.fetch!(:value)
  end

  config :ex_aws,
    http_client: Plausible.S3.Client,
    access_key_id: s3_env_value.("S3_ACCESS_KEY_ID"),
    secret_access_key: s3_env_value.("S3_SECRET_ACCESS_KEY"),
    region: s3_env_value.("S3_REGION")

  %URI{scheme: s3_scheme, host: s3_host, port: s3_port} = URI.parse(s3_env_value.("S3_ENDPOINT"))

  config :ex_aws, :s3,
    scheme: s3_scheme <> "://",
    host: s3_host,
    port: s3_port

  config :plausible, Plausible.S3,
    exports_bucket: s3_env_value.("S3_EXPORTS_BUCKET"),
    imports_bucket: s3_env_value.("S3_IMPORTS_BUCKET")
end

config :plausible, Plausible.Cache.Adapter, sessions: [partitions: 100]

config :phoenix_storybook, enabled: env !== "prod"
