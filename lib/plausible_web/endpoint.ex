defmodule PlausibleWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :plausible
  use Sentry.Phoenix.Endpoint

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :plausible,
    gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  plug Plug.Session,
    store: :cookie,
    key: "_plausible_key",
    signing_salt: "3IL0ob4k",
    max_age: 60*60*24*365*5, # 5 years, this is super long but the SlidingSessionTimeout will log people out if they don't return for 2 weeks
    extra: "SameSite=Strict"


  plug CORSPlug
  plug PlausibleWeb.Router

  def clean_url() do
    url = PlausibleWeb.Endpoint.url

    if Mix.env() == :prod do
      URI.parse(url) |> Map.put(:port, nil) |> URI.to_string()
    else
      url
    end
  end
end
