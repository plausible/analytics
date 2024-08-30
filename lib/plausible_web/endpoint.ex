defmodule PlausibleWeb.Endpoint do
  use Plausible
  use Sentry.PlugCapture
  use Phoenix.Endpoint, otp_app: :plausible

  on_ce do
    plug :maybe_handle_acme_challenge
    plug :maybe_force_ssl, Plug.SSL.init(_no_opts = [])
  end

  @session_options [
    # key to be patched
    key: "",
    store: :cookie,
    signing_salt: "I45i0SKHEku2f3tJh6y4v8gztrb/eG5KGCOe/o/AwFb7VHeuvDOn7AAq6KsdmOFM",
    # 5 years, this is super long but the SlidingSessionTimeout will log people out if they don't return for 2 weeks
    max_age: 60 * 60 * 24 * 365 * 5,
    extra: "SameSite=Lax"
    # domain added dynamically via RuntimeSessionAdapter, see below
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
  plug(PlausibleWeb.Tracker)
  plug(PlausibleWeb.Favicon)

  static_paths = ~w(css js images favicon.ico)

  static_paths =
    on_ee do
      # NOTE: The Cloud uses custom robots.txt from https://github.com/plausible/website: https://plausible.io/robots.txt
      static_paths
    else
      static_paths ++ ["robots.txt"]
    end

  plug(Plug.Static,
    at: "/",
    from: :plausible,
    gzip: false,
    only: static_paths
  )

  on_ee do
    plug(Plug.Static,
      at: "/kaffy",
      from: :kaffy,
      gzip: false,
      only: ~w(assets)
    )
  end

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

  def runtime_session(conn, _opts) do
    Plug.run(conn, [{Plug.Session, runtime_session_opts()}])
  end

  def runtime_session_opts() do
    # `host()` provided by Phoenix.Endpoint's compilation hooks
    # is used to inject the domain - this way we can authenticate
    # websocket requests within single root domain, in case websocket_url()
    # returns a ws{s}:// scheme (in which case SameSite=Lax is not applicable).
    @session_options
    |> Keyword.put(:domain, host())
    |> Keyword.put(:key, "_plausible_#{Application.fetch_env!(:plausible, :environment)}")
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
    @https_key {:plausible, :https}

    @doc false
    def enable_https(force?) when is_boolean(force?) do
      # this function is called from application.ex during app start up
      :persistent_term.put(@https_key, force?)
    end

    defp https?, do: :persistent_term.get(@https_key)

    defp maybe_handle_acme_challenge(conn, _opts) do
      if https?() do
        SiteEncrypt.AcmeChallenge.call(conn, _endpoint = __MODULE__)
      else
        conn
      end
    end

    defp maybe_force_ssl(conn, opts) do
      if https?() do
        Plug.SSL.call(conn, opts)
      else
        conn
      end
    end

    @impl SiteEncrypt
    def handle_new_cert, do: :ok

    @doc false
    def app_env_config do
      # this function is also being used by site_encrypt
      Application.get_env(:plausible, _endpoint = __MODULE__, [])
    end

    @impl SiteEncrypt
    def certification do
      domain =
        app_env_config()
        |> Keyword.fetch!(:url)
        |> Keyword.fetch!(:host)

      domain_is_ip? =
        case :inet.parse_address(to_charlist(domain)) do
          {:ok, _address} -> true
          _other -> false
        end

      domain_is_local? = domain == "localhost" or not String.contains?(domain, ".")

      if domain_is_ip? or domain_is_local? do
        raise ArgumentError, "Cannot generate TLS certificates for domain #{inspect(domain)}"
      end

      email =
        case PlausibleWeb.Email.mailer_email_from() do
          {_, email} -> email
          email when is_binary(email) -> email
        end

      data_dir = Application.get_env(:plausible, :data_dir)
      db_folder = Path.join(data_dir || System.tmp_dir!(), "site_encrypt")

      directory_url =
        Application.get_env(:plausible, :acme_directory_url) ||
          "https://acme-v02.api.letsencrypt.org/directory"

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
