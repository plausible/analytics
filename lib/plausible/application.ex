defmodule Plausible.Application do
  @moduledoc false

  use Application

  require Logger

  def start(_type, _args) do
    children = [
      Plausible.Repo,
      Plausible.ClickhouseRepo,
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
      PlausibleWeb.Endpoint,
      {Oban, Application.get_env(:plausible, Oban)},
      Plausible.PromEx
    ]

    opts = [strategy: :one_for_one, name: Plausible.Supervisor]
    setup_sentry()
    OpentelemetryPhoenix.setup()
    OpentelemetryEcto.setup([:plausible, :repo])
    OpentelemetryEcto.setup([:plausible, :clickhouse_repo])
    Location.load_all()
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    PlausibleWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp finch_pool_config() do
    config = Application.fetch_env!(:plausible, Plausible.Finch)

    pool_config = %{
      :default => [size: config[:default_pool_size], count: config[:default_pool_count]],
      "https://vendors.paddle.com" => [
        protocol: :http2,
        count: 50,
        conn_opts: [transport_opts: [timeout: 15_000]]
      ],
      "https://www.googleapis.com" => [
        protocol: :http2,
        count: 200,
        conn_opts: [transport_opts: [timeout: 15_000]]
      ],
      "https://analyticsreporting.googleapis.com" => [
        protocol: :http2,
        count: 200,
        conn_opts: [transport_opts: [timeout: 15_000]]
      ],
      "https://icons.duckduckgo.com" => [
        protocol: :http2,
        count: 100,
        conn_opts: [transport_opts: [timeout: 15_000]]
      ]
    }

    sentry_dsn = Application.get_env(:sentry, :dsn)

    if is_binary(sentry_dsn) do
      Map.put(pool_config, sentry_dsn,
        size: config[:sentry_pool_size],
        count: config[:sentry_pool_count]
      )
    else
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
end
