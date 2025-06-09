defmodule PlausibleWeb.Endpoint do
  use Plausible
  use Sentry.PlugCapture
  use Phoenix.Endpoint, otp_app: :plausible

  on_ce do
    plug :maybe_handle_acme_challenge
    plug :maybe_force_ssl, Plug.SSL.init(_no_opts = [])
  end

  @session_options [
    # in EE key is replaced dynamically via runtime_session_opts, see below
    key: "_plausible_key",
    store: :cookie,
    signing_salt: "I45i0SKHEku2f3tJh6y4v8gztrb/eG5KGCOe/o/AwFb7VHeuvDOn7AAq6KsdmOFM",
    # 5 years, this is super long but the SlidingSessionTimeout will log people out if they don't return for 2 weeks
    max_age: 60 * 60 * 24 * 365 * 5,
    extra: "SameSite=Lax"
    # in EE domain is added dynamically via runtime_session_opts, see below
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

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug(PlausibleWeb.TrackerPlug)
  plug(PlausibleWeb.Favicon)

  static_paths = ~w(css js images favicon.ico)

  static_paths =
    on_ee do
      # NOTE: The Cloud uses custom robots.txt from https://github.com/plausible/website: https://plausible.io/robots.txt
      static_paths
    else
      static_paths ++ ["robots.txt"]
    end

  static_compression =
    if ce?() do
      [brotli: true, gzip: true]
    else
      [gzip: false]
    end

  plug(
    Plug.Static,
    [at: "/", from: :plausible, only: static_paths] ++ static_compression
  )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

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
  plug(PlausibleWeb.Router)

  def secure_cookie?, do: config!(:secure_cookie)

  def websocket_url() do
    config!(:websocket_url)
  end

  def ingestion_url() do
    # :KLUDGE: Normally, we would use Phoenix.Endpoint.url() here, but that requires the endpoint to be started.
    # However we start TrackerScriptCache before the endpoint is started, so we need to use the base_url directly.
    base_url = config!(:base_url)
    "#{base_url}/api/event"
  end

  def runtime_session(conn, _opts) do
    Plug.run(conn, [{Plug.Session, runtime_session_opts()}])
  end

  def runtime_session_opts() do
    session_options =
      on_ee do
        # `host()` provided by Phoenix.Endpoint's compilation hooks
        # is used to inject the domain - this way we can authenticate
        # websocket requests within single root domain, in case websocket_url()
        # returns a ws{s}:// scheme (in which case SameSite=Lax is not applicable).
        Keyword.put(@session_options, :domain, host())
        |> Keyword.put(:key, "_plausible_#{Application.fetch_env!(:plausible, :environment)}")
      else
        # CE setup is simpler and we don't need to worry about WS domain being different
        @session_options
      end

    session_options
    |> Keyword.put(:secure, secure_cookie?())
  end

  defp config!(key) do
    :plausible
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(key)
  end

  on_ce do
    require SiteEncrypt
    @behaviour SiteEncrypt
    @force_https_key {:plausible, :force_https}
    @allow_acme_challenges_key {:plausible, :allow_acme_challenges}

    @doc false
    def force_https do
      :persistent_term.put(@force_https_key, true)
    end

    @doc false
    def allow_acme_challenges do
      :persistent_term.put(@allow_acme_challenges_key, true)
    end

    defp maybe_handle_acme_challenge(conn, _opts) do
      if :persistent_term.get(@allow_acme_challenges_key, false) do
        SiteEncrypt.AcmeChallenge.call(conn, _endpoint = __MODULE__)
      else
        conn
      end
    end

    defp maybe_force_ssl(conn, opts) do
      if :persistent_term.get(@force_https_key, false) do
        Plug.SSL.call(conn, opts)
      else
        conn
      end
    end

    @impl SiteEncrypt
    def handle_new_cert, do: :ok

    @doc false
    def app_env_config do
      # this function is being used by site_encrypt
      Application.get_env(:plausible, _endpoint = __MODULE__, [])
    end

    @impl SiteEncrypt
    def certification do
      selfhost_config = Application.fetch_env!(:plausible, :selfhost)
      config = Keyword.fetch!(selfhost_config, :site_encrypt)

      domain = Keyword.fetch!(config, :domain)
      email = Keyword.fetch!(config, :email)
      db_folder = Keyword.fetch!(config, :db_folder)
      directory_url = Keyword.fetch!(config, :directory_url)

      SiteEncrypt.configure(
        mode: :auto,
        log_level: :notice,
        client: :certbot,
        domains: [domain],
        emails: [email],
        db_folder: db_folder,
        directory_url: directory_url
      )
    end
  end
end
