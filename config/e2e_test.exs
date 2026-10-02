import Config

config :plausible, PlausibleWeb.Endpoint,
  server: true,
  check_origin: false

config :plausible,
  paddle_api: Plausible.Billing.DevPaddleApiMock,
  google_api: Plausible.Google.API.Mock,
  verification_checks_mod: Plausible.InstallationSupport.Verification.ChecksMock

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

config :bcrypt_elixir, :log_rounds, 4

config :plausible, Plausible.Ingestion.Counters, enabled: false

config :plausible, Oban, testing: :manual

config :plausible, Plausible.Session.Salts, interval: :timer.hours(1)

# The consent flow fetches its client's metadata document over HTTP. Both ends
# are stood in for locally: the name resolves to a public address so the SSRF
# guard allows it, and a plug serves the document instead of the network.
config :plausible, :dns_lookup_impl, PlausibleWeb.E2E.DnsLookup

config :plausible, Plausible.OAuth.CIMD, req_opts: [plug: PlausibleWeb.E2E.OAuthClient]
