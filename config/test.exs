import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :plausible, PlausibleWeb.Endpoint, server: false

config :bcrypt_elixir, :log_rounds, 4

config :plausible, Plausible.Repo, pool: Ecto.Adapters.SQL.Sandbox

config :plausible, Plausible.ClickhouseRepo,
  loggers: [Ecto.LogEntry],
  pool_size: 5

config :plausible, Plausible.Mailer, adapter: Bamboo.TestAdapter

config :plausible,
  paddle_api: Plausible.PaddleApi.Mock,
  google_api: Plausible.Google.Api.Mock

config :plausible, :google,
  client_id: "fake_client_id",
  client_secret: "fake_client_secret"

config :bamboo, :refute_timeout, 10

geolix_sample_lookup = %{
  city: %{geoname_id: 2_988_507, names: %{en: "Paris"}},
  continent: %{code: "EU", geoname_id: 6_255_148, names: %{en: "Europe"}},
  country: %{
    geoname_id: 3_017_382,
    is_in_european_union: true,
    iso_code: "FR",
    names: %{en: "France"}
  },
  ip_address: {2, 2, 2, 2},
  location: %{
    latitude: 48.8566,
    longitude: 2.35222,
    time_zone: "Europe/Paris",
    weather_code: "FRXX0076"
  },
  postal: %{code: "75000"},
  subdivisions: [
    %{geoname_id: 3_012_874, iso_code: "IDF", names: %{en: "Île-de-France"}},
    %{geoname_id: 2_968_815, iso_code: "75", names: %{en: "Paris"}}
  ]
}

config :geolix,
  databases: [
    %{
      id: :geolocation,
      adapter: Geolix.Adapter.Fake,
      data: %{
        {1, 1, 1, 1} => %{country: %{iso_code: "US"}},
        {2, 2, 2, 2} => geolix_sample_lookup,
        {1, 1, 1, 1, 1, 1, 1, 1} => %{country: %{iso_code: "US"}},
        {0, 0, 0, 0} => %{country: %{iso_code: "ZZ"}}
      }
    }
  ]

config :plausible,
  session_timeout: 0,
  http_impl: Plausible.HTTPClient.Mock
