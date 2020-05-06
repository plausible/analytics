import Config

### Mandatory params Start
# it is highly recommended to change this parameters in production systems
# params are made optional to facilitate smooth release

port = System.get_env("PORT") || 8000
host = System.get_env("HOST","localhost")
secret_key_base = System.get_env("SECRET_KEY_BASE","/NJrhNtbyCVAsTyvtk1ZYCwfm981Vpo/0XrVwjJvemDaKC/vsvBRevLwsc6u8RCg")
db_pool_size = String.to_integer(System.get_env("DATABASE_POOL_SIZE", "10"))
db_url = System.get_env("DATABASE_URL","postgres://postgres:postgres@127.0.0.1:5432/plausible_test?currentSchema=default")
db_tls_enabled? = String.to_existing_atom(System.get_env("DATABASE_TLS_ENABLED", "false"))
### Mandatory params End

sentry_dsn = System.get_env("SENTRY_DSN")
paddle_auth_code = System.get_env("PADDLE_VENDOR_AUTH_CODE")
google_cid = System.get_env("GOOGLE_CLIENT_ID")
google_secret = System.get_env("GOOGLE_CLIENT_SECRET")
slack_hook_url = System.get_env("SLACK_WEBHOOK")
twitter_consumer_key = System.get_env("TWITTER_CONSUMER_KEY")
twitter_consumer_secret = System.get_env("TbWITTER_CONSUMER_SECRET")
twitter_token = System.get_env("TWITTER_ACCESS_TOKEN")
twitter_token_secret = System.get_env("TWITTER_ACCESS_TOKEN_SECRET")
postmark_api_key = System.get_env("POSTMARK_API_KEY")

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
       timeout: 10_000,
       ssl: db_tls_enabled?

config :sentry,
  dsn: sentry_dsn

config :plausible, :paddle, vendor_auth_code: paddle_auth_code

config :plausible, :google,
  client_id: google_cid,
  client_secret: google_secret

config :plausible, :slack, webhook: slack_hook_url

config :plausible, Plausible.Mailer,
  adapter: Bamboo.PostmarkAdapter,
  api_key: postmark_api_key

config :plausible, :twitter,
  consumer_key: twitter_consumer_key,
  consumer_secret: twitter_consumer_secret,
  token: twitter_token,
  token_secret: twitter_token_secret

config :logger, level: :warn