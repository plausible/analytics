defmodule Plausible.Application do
  @moduledoc false

  use Application
  use Plausible

  require Logger

  def start(_type, _args) do
    on_ee(do: Plausible.License.ensure_valid_license())
    on_ce(do: :inet_db.set_tcp_module(:happy_tcp))

    # in CE we start the endpoint under site_encrypt for automatic https
    endpoint = on_ee(do: PlausibleWeb.Endpoint, else: maybe_https_endpoint())

    children =
      [
        Plausible.Session.BalancerSupervisor,
        Plausible.Cache.Stats,
        Plausible.PromEx,
        {Plausible.Auth.TOTP.Vault, key: totp_vault_key()},
        Plausible.Repo,
        Plausible.ClickhouseRepo,
        Plausible.IngestRepo,
        Plausible.AsyncInsertRepo,
        Plausible.ImportDeletionRepo,
        Plausible.Cache.Adapter.child_spec(:customer_currency, :cache_customer_currency,
          ttl_check_interval: :timer.minutes(5),
          n_lock_partitions: 1,
          global_ttl: :timer.minutes(60)
        ),
        Plausible.Cache.Adapter.child_spec(:user_agents, :cache_user_agents,
          ttl_check_interval: :timer.minutes(5),
          global_ttl: :timer.minutes(60),
          n_lock_partitions: 1,
          ets_options: [read_concurrency: true, write_concurrency: true]
        ),
        Plausible.Cache.Adapter.child_specs(:sessions, :cache_sessions,
          ttl_check_interval: :timer.seconds(10),
          global_ttl: :timer.minutes(30),
          n_lock_partitions: 1,
          ets_options: [read_concurrency: true, write_concurrency: true]
        ),
        warmed_cache(Plausible.Site.Cache,
          adapter_opts: [
            n_lock_partitions: 1,
            ttl_check_interval: false,
            ets_options: [read_concurrency: true]
          ],
          warmers: [
            refresh_all:
              {Plausible.Site.Cache.All,
               interval: :timer.minutes(15) + Enum.random(1..:timer.seconds(10))},
            refresh_updated_recently:
              {Plausible.Site.Cache.RecentlyUpdated, interval: :timer.seconds(30)}
          ]
        ),
        warmed_cache(Plausible.Shield.IPRuleCache,
          adapter_opts: [
            n_lock_partitions: 1,
            ttl_check_interval: false,
            ets_options: [read_concurrency: true]
          ],
          warmers: [
            refresh_all:
              {Plausible.Shield.IPRuleCache.All,
               interval: :timer.minutes(3) + Enum.random(1..:timer.seconds(10))},
            refresh_updated_recently:
              {Plausible.Shield.IPRuleCache.RecentlyUpdated, interval: :timer.seconds(35)}
          ]
        ),
        warmed_cache(Plausible.Shield.CountryRuleCache,
          adapter_opts: [
            n_lock_partitions: 1,
            ttl_check_interval: false,
            ets_options: [read_concurrency: true]
          ],
          warmers: [
            refresh_all:
              {Plausible.Shield.CountryRuleCache.All,
               interval: :timer.minutes(3) + Enum.random(1..:timer.seconds(10))},
            refresh_updated_recently:
              {Plausible.Shield.CountryRuleCache.RecentlyUpdated, interval: :timer.seconds(35)}
          ]
        ),
        warmed_cache(Plausible.Shield.PageRuleCache,
          adapter_opts: [
            n_lock_partitions: 1,
            ttl_check_interval: false,
            ets_options: [:bag, read_concurrency: true]
          ],
          warmers: [
            refresh_all:
              {Plausible.Shield.PageRuleCache.All,
               interval: :timer.minutes(3) + Enum.random(1..:timer.seconds(10))},
            refresh_updated_recently:
              {Plausible.Shield.PageRuleCache.RecentlyUpdated, interval: :timer.seconds(35)}
          ]
        ),
        warmed_cache(Plausible.Shield.HostnameRuleCache,
          adapter_opts: [
            n_lock_partitions: 1,
            ttl_check_interval: false,
            ets_options: [:bag, read_concurrency: true]
          ],
          warmers: [
            refresh_all:
              {Plausible.Shield.HostnameRuleCache.All,
               interval: :timer.minutes(3) + Enum.random(1..:timer.seconds(10))},
            refresh_updated_recently:
              {Plausible.Shield.HostnameRuleCache.RecentlyUpdated, interval: :timer.seconds(25)}
          ]
        ),
        on_ee do
          warmed_cache(Plausible.Stats.SamplingCache,
            adapter_opts: [
              n_lock_partitions: 1,
              ttl_check_interval: false,
              read_concurrency: true
            ],
            warmers: [
              refresh_all:
                {Plausible.Stats.SamplingCache.All,
                 interval: :timer.hours(24) + Enum.random(1..:timer.minutes(60))}
            ]
          )
        end,
        Plausible.Ingestion.Counters,
        Plausible.Session.Salts,
        Supervisor.child_spec(Plausible.Event.WriteBuffer, id: Plausible.Event.WriteBuffer),
        Supervisor.child_spec(Plausible.Session.WriteBuffer, id: Plausible.Session.WriteBuffer),
        ReferrerBlocklist,
        {Plausible.RateLimit, clean_period: :timer.minutes(10)},
        {Finch, name: Plausible.Finch, pools: finch_pool_config()},
        {Phoenix.PubSub, name: Plausible.PubSub},
        endpoint,
        {Oban, Application.get_env(:plausible, Oban)},
        on_ee do
          help_scout_vault()
        end
      ]
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    opts = [strategy: :one_for_one, name: Plausible.Supervisor]

    setup_request_logging()
    setup_sentry()
    setup_opentelemetry()

    setup_geolocation()
    Location.load_all()
    Plausible.Ingestion.Source.init()
    Plausible.Geo.await_loader()

    Supervisor.start_link(List.flatten(children), opts)
  end

  def config_change(changed, _new, removed) do
    PlausibleWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  on_ee do
    defp help_scout_vault() do
      help_scout_vault_key =
        :plausible
        |> Application.fetch_env!(Plausible.HelpScout)
        |> Keyword.fetch!(:vault_key)
        |> Base.decode64!()

      [{Plausible.HelpScout.Vault, key: help_scout_vault_key}]
    end
  end

  defp totp_vault_key() do
    :plausible
    |> Application.fetch_env!(Plausible.Auth.TOTP)
    |> Keyword.fetch!(:vault_key)
  end

  defp finch_pool_config() do
    default = Application.get_env(:plausible, Plausible.Finch)

    base_config =
      if default do
        %{default: default}
      else
        %{}
      end

    default_opts = default || []

    base_config
    |> Map.put(
      "https://icons.duckduckgo.com",
      Config.Reader.merge(default_opts, conn_opts: [transport_opts: [timeout: 15_000]])
    )
    |> maybe_add_sentry_pool(default_opts)
    |> maybe_add_paddle_pool(default_opts)
    |> maybe_add_google_pools(default_opts)
  end

  defp maybe_add_sentry_pool(pool_config, default) do
    case Sentry.Config.dsn() do
      %{endpoint_uri: "http" <> _rest = url} ->
        Map.put(pool_config, url, Config.Reader.merge(default, size: 50))

      nil ->
        pool_config
    end
  end

  defp maybe_add_paddle_pool(pool_config, default) do
    paddle_conf = Application.get_env(:plausible, :paddle)

    cond do
      paddle_conf[:vendor_id] && paddle_conf[:vendor_auth_code] ->
        Map.put(
          pool_config,
          Plausible.Billing.PaddleApi.vendors_domain(),
          Config.Reader.merge(default, conn_opts: [transport_opts: [timeout: 15_000]])
        )

      true ->
        pool_config
    end
  end

  defp maybe_add_google_pools(pool_config, default) do
    google_conf = Application.get_env(:plausible, :google)

    cond do
      google_conf[:client_id] && google_conf[:client_secret] ->
        pool_config
        |> Map.put(
          google_conf[:api_url],
          Config.Reader.merge(default, conn_opts: [transport_opts: [timeout: 15_000]])
        )
        |> Map.put(
          google_conf[:reporting_api_url],
          Config.Reader.merge(default, conn_opts: [transport_opts: [timeout: 15_000]])
        )

      true ->
        pool_config
    end
  end

  def setup_request_logging() do
    :telemetry.attach(
      "plausible-request-logging",
      [:phoenix, :endpoint, :stop],
      &Plausible.RequestLogger.log_request/4,
      %{}
    )
  end

  def setup_sentry() do
    Logger.add_backend(Sentry.LoggerBackend)

    :telemetry.attach_many(
      "oban-errors",
      [[:oban, :job, :exception], [:oban, :notifier, :exception], [:oban, :plugin, :exception]],
      &ObanErrorReporter.handle_event/4,
      %{}
    )
  end

  defp setup_opentelemetry() do
    OpentelemetryPhoenix.setup()
    OpentelemetryEcto.setup([:plausible, :repo])
    OpentelemetryEcto.setup([:plausible, :clickhouse_repo])
    OpentelemetryOban.setup()
  end

  defp setup_geolocation do
    opts = Application.fetch_env!(:plausible, Plausible.Geo)
    :ok = Plausible.Geo.load_db(opts)
  end

  defp warmed_cache(impl_mod, opts) when is_atom(impl_mod) and is_list(opts) do
    warmers = Keyword.fetch!(opts, :warmers)

    warmer_specs =
      Enum.map(warmers, fn {warmer_fn, {warmer_id, warmer_opts}} ->
        {Plausible.Cache.Warmer,
         Keyword.merge(
           [
             child_name: warmer_id,
             cache_impl: impl_mod,
             warmer_fn: warmer_fn
           ],
           warmer_opts
         )}
      end)

    [{impl_mod, Keyword.fetch!(opts, :adapter_opts)} | warmer_specs]
  end

  on_ce do
    defp maybe_https_endpoint do
      endpoint_config = Application.fetch_env!(:plausible, PlausibleWeb.Endpoint)
      selfhost_config = Application.fetch_env!(:plausible, :selfhost)
      site_encrypt_config = Keyword.get(selfhost_config, :site_encrypt)

      if get_in(endpoint_config, [:https, :port]) do
        PlausibleWeb.Endpoint.force_https()
      end

      if site_encrypt_config do
        PlausibleWeb.Endpoint.allow_acme_challenges()
        {SiteEncrypt.Phoenix.Endpoint, endpoint: PlausibleWeb.Endpoint}
      else
        PlausibleWeb.Endpoint
      end
    end
  end
end
