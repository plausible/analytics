import Config

port = System.fetch_env!("PORT")
host = System.fetch_env!("HOST")
secret_key_base = System.fetch_env!("SECRET_KEY_BASE")
sentry_dsn = System.get_env("SENTRY_DSN")
paddle_auth_code = System.get_env("PADDLE_VENDOR_AUTH_CODE")
db_pool_size = String.to_integer(System.get_env("DATABASE_POOL_SIZE", "10"))
db_url = System.fetch_env!("DATABASE_URL")
google_cid = System.get_env("GOOGLE_CLIENT_ID")
google_secret = System.get_env("GOOGLE_CLIENT_SECRET")
slack_hook_url = System.get_env("SLACK_WEBHOOK")
twitter_consumer_key = System.get_env("TWITTER_CONSUMER_KEY")
twitter_consumer_secret = System.get_env("TWITTER_CONSUMER_SECRET")
twitter_token = System.get_env("TWITTER_ACCESS_TOKEN")
twitter_token_secret = System.get_env("TWITTER_ACCESS_TOKEN_SECRET")
postmark_api_key = System.get_env("POSTMARK_API_KEY")

config :sentry,
  dsn: sentry_dsn

config :plausible, :paddle, vendor_auth_code: paddle_auth_code

config :plausible,
       Plausible.Repo,
       pool_size: db_pool_size,
       url: db_url

config :plausible, PlausibleWeb.Endpoint, secret_key_base: secret_key_base

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
