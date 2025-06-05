defmodule PlausibleWeb.InternalEndpoint do
  @moduledoc """
  Superadmin area endpoint
  """

  use Sentry.PlugCapture
  use Phoenix.Endpoint, otp_app: :plausible

  plug(Plug.RequestId)
  plug(PromEx.Plug, prom_ex_module: Plausible.PromEx)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint], log: false)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Sentry.PlugContext)

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  plug(:runtime_session)

  plug(CORSPlug)

  plug(PlausibleWeb.Favicon)

  plug(
    Plug.Static,
    at: "/",
    from: :plausible,
    only: ~w(css js images favicon.ico)
  )

  plug(PlausibleWeb.InternalRouter)

  @session_options [
    key: "_plausible_key",
    store: :cookie,
    signing_salt: "I45i0SKHEku2f3tJh6y4v8gztrb/eG5KGCOe/o/AwFb7VHeuvDOn7AAq6KsdmOFM",
    # 5 years, this is super long but the SlidingSessionTimeout will log people out if they don't return for 2 weeks
    max_age: 60 * 60 * 24 * 365 * 5,
    extra: "SameSite=Lax"
  ]

  socket("/live", Phoenix.LiveView.Socket,
    websocket: [
      check_origin: true,
      connect_info: [
        :peer_data,
        :uri,
        :user_agent,
        session: {__MODULE__, :runtime_session_opts, []}
      ]
    ]
  )

  def runtime_session(conn, _opts) do
    Plug.run(conn, [{Plug.Session, runtime_session_opts()}])
  end

  def runtime_session_opts() do
    # `host()` provided by Phoenix.Endpoint's compilation hooks
    # is used to inject the domain - this way we can authenticate
    # websocket requests within single root domain, in case websocket_url()
    # returns a ws{s}:// scheme (in which case SameSite=Lax is not applicable).
    session_options =
      Keyword.put(@session_options, :domain, host())
      |> Keyword.put(:key, "_plausible_#{Application.fetch_env!(:plausible, :environment)}")

    session_options
    |> Keyword.put(:secure, secure_cookie?())
  end

  def secure_cookie?, do: config!(:secure_cookie)

  defp config!(key) do
    :plausible
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(key)
  end
end
