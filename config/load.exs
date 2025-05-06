import Config

config :plausible, PlausibleWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  check_origin: false,
  server: true,
  code_reloader: false,
  http: [
    transport_options: [
      num_acceptors: 1000
    ]
  ],
  protocol_options: [
    max_keepalive: 5_000,
    idle_timeout: 120_000,
    request_timeout: 120_000
  ]
