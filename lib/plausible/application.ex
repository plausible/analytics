defmodule Plausible.Application do
  @moduledoc false

  use Application

  require Logger

  def start(_type, _args) do
    children = [
      Plausible.Repo,
      Plausible.ClickhouseRepo,
      Plausible.IngestRepo,
      Plausible.AsyncInsertRepo,
      Plausible.ImportDeletionRepo,
      Plausible.Ingestion.Counters,
      {Finch, name: Plausible.Finch, pools: finch_pool_config()},
      {Phoenix.PubSub, name: Plausible.PubSub},
      Plausible.Session.Salts,
      Plausible.Event.WriteBuffer,
      Plausible.Session.WriteBuffer,
      ReferrerBlocklist,
      Supervisor.child_spec({Cachex, name: :user_agents, limit: 10_000, stats: true},
        id: :cachex_user_agents
      ),
      Supervisor.child_spec({Cachex, name: :sessions, limit: nil, stats: true},
        id: :cachex_sessions
      ),
      {Plausible.Site.Cache, []},
      {Plausible.Site.Cache.Warmer.All, []},
      {Plausible.Site.Cache.Warmer.RecentlyUpdated, []},
      PlausibleWeb.Endpoint,
      {Oban, Application.get_env(:plausible, Oban)},
      Plausible.PromEx
    ]

    opts = [strategy: :one_for_one, name: Plausible.Supervisor]

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
      dsn when is_binary(dsn) ->
        Map.put(pool_config, dsn, size: 50)

      _ ->
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
        |> Map.put(google_conf[:reporting_api_url], conn_opts: [transport_opts: [timeout: 15_000]])

      true ->
        pool_config
    end
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

  def report_cache_stats() do
    case Cachex.stats(:user_agents) do
      {:ok, stats} ->
        Logger.info("User agent cache stats: #{inspect(stats)}")

      e ->
        IO.puts("Unable to show cache stats: #{inspect(e)}")
    end
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
