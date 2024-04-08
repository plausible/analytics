defmodule Plausible.Application do
  @moduledoc false

  use Application
  use Plausible

  require Logger

  def start(_type, _args) do
    on_full_build(do: Plausible.License.ensure_valid_license())

    children = [
      Plausible.Cache.Stats,
      Plausible.Repo,
      Plausible.ClickhouseRepo,
      Plausible.IngestRepo,
      Plausible.AsyncInsertRepo,
      Plausible.ImportDeletionRepo,
      {Plausible.RateLimit, clean_period: :timer.minutes(10)},
      Plausible.Ingestion.Counters,
      {Finch, name: Plausible.Finch, pools: finch_pool_config()},
      {Phoenix.PubSub, name: Plausible.PubSub},
      Plausible.Session.Salts,
      Supervisor.child_spec(Plausible.Event.WriteBuffer, id: Plausible.Event.WriteBuffer),
      Supervisor.child_spec(Plausible.Session.WriteBuffer, id: Plausible.Session.WriteBuffer),
      ReferrerBlocklist,
      Plausible.Cache.Adapter.child_spec(:user_agents, :cache_user_agents,
        ttl_check_interval: :timer.seconds(5),
        global_ttl: :timer.minutes(60)
      ),
      Plausible.Cache.Adapter.child_spec(:sessions, :cache_sessions,
        ttl_check_interval: :timer.seconds(1),
        global_ttl: :timer.minutes(30)
      ),
      {Plausible.Site.Cache, ttl_check_interval: false},
      {Plausible.Cache.Warmer,
       [
         child_name: Plausible.Site.Cache.All,
         cache_impl: Plausible.Site.Cache,
         interval: :timer.minutes(15) + Enum.random(1..:timer.seconds(10)),
         warmer_fn: :refresh_all
       ]},
      {Plausible.Cache.Warmer,
       [
         child_name: Plausible.Site.Cache.RecentlyUpdated,
         cache_impl: Plausible.Site.Cache,
         interval: :timer.seconds(30),
         warmer_fn: :refresh_updated_recently
       ]},
      {Plausible.Shield.IPRuleCache, ttl_check_interval: false},
      {Plausible.Cache.Warmer,
       [
         child_name: Plausible.Shield.IPRuleCache.All,
         cache_impl: Plausible.Shield.IPRuleCache,
         interval: :timer.minutes(3) + Enum.random(1..:timer.seconds(10)),
         warmer_fn: :refresh_all
       ]},
      {Plausible.Cache.Warmer,
       [
         child_name: Plausible.Shield.IPRuleCache.RecentlyUpdated,
         cache_impl: Plausible.Shield.IPRuleCache,
         interval: :timer.seconds(35),
         warmer_fn: :refresh_updated_recently
       ]},
      {Plausible.Shield.CountryRuleCache, ttl_check_interval: false},
      {Plausible.Cache.Warmer,
       [
         child_name: Plausible.Shield.CountryRuleCache.All,
         cache_impl: Plausible.Shield.CountryRuleCache,
         interval: :timer.minutes(3) + Enum.random(1..:timer.seconds(10)),
         warmer_fn: :refresh_all
       ]},
      {Plausible.Cache.Warmer,
       [
         child_name: Plausible.Shield.CountryRuleCache.RecentlyUpdated,
         cache_impl: Plausible.Shield.CountryRuleCache,
         interval: :timer.seconds(35),
         warmer_fn: :refresh_updated_recently
       ]},
      {Plausible.Shield.PageRuleCache, ttl_check_interval: false, ets_options: [:bag]},
      {Plausible.Cache.Warmer,
       [
         child_name: Plausible.Shield.PageRuleCache.All,
         cache_impl: Plausible.Shield.PageRuleCache,
         interval: :timer.minutes(3) + Enum.random(1..:timer.seconds(10)),
         warmer_fn: :refresh_all
       ]},
      {Plausible.Cache.Warmer,
       [
         child_name: Plausible.Shield.PageRuleCache.RecentlyUpdated,
         cache_impl: Plausible.Shield.PageRuleCache,
         interval: :timer.seconds(35),
         warmer_fn: :refresh_updated_recently
       ]},
      {Plausible.Auth.TOTP.Vault, key: totp_vault_key()},
      PlausibleWeb.Endpoint,
      {Oban, Application.get_env(:plausible, Oban)},
      Plausible.PromEx
    ]

    opts = [strategy: :one_for_one, name: Plausible.Supervisor]

    setup_request_logging()
    setup_sentry()
    setup_opentelemetry()

    setup_geolocation()
    Location.load_all()
    Plausible.Geo.await_loader()

    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    PlausibleWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp totp_vault_key() do
    :plausible
    |> Application.fetch_env!(Plausible.Auth.TOTP)
    |> Keyword.fetch!(:vault_key)
    |> Base.decode64!()
  end

  defp finch_pool_config() do
    base_config = %{
      "https://icons.duckduckgo.com" => [
        conn_opts: [transport_opts: [timeout: 15_000]]
      ]
    }

    base_config
    |> maybe_add_sentry_pool()
    |> maybe_add_paddle_pool()
    |> maybe_add_google_pools()
  end

  defp maybe_add_sentry_pool(pool_config) do
    case Sentry.Config.dsn() do
      {"http" <> _rest = url, _, _} ->
        Map.put(pool_config, url, size: 50)

      nil ->
        pool_config
    end
  end

  defp maybe_add_paddle_pool(pool_config) do
    paddle_conf = Application.get_env(:plausible, :paddle)

    cond do
      paddle_conf[:vendor_id] && paddle_conf[:vendor_auth_code] ->
        Map.put(pool_config, Plausible.Billing.PaddleApi.vendors_domain(),
          conn_opts: [transport_opts: [timeout: 15_000]]
        )

      true ->
        pool_config
    end
  end

  defp maybe_add_google_pools(pool_config) do
    google_conf = Application.get_env(:plausible, :google)

    cond do
      google_conf[:client_id] && google_conf[:client_secret] ->
        pool_config
        |> Map.put(google_conf[:api_url], conn_opts: [transport_opts: [timeout: 15_000]])
        |> Map.put(google_conf[:reporting_api_url],
          conn_opts: [transport_opts: [timeout: 15_000]]
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
end
