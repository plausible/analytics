defmodule Plausible.Application do
  @moduledoc false

  use Application

  require Logger

  def start(_type, _args) do
    children = [
      Plausible.Repo,
      Plausible.ClickhouseRepo,
      {Phoenix.PubSub, name: Plausible.PubSub},
      Plausible.Session.Salts,
      Plausible.Event.WriteBuffer,
      Plausible.Session.WriteBuffer,
      Plausible.Session.Store,
      ReferrerBlocklist,
      Supervisor.child_spec({Cachex, name: :user_agents, limit: 1000}, id: :cachex_user_agents),
      Supervisor.child_spec({Cachex, name: :sessions, limit: nil}, id: :cachex_sessions),
      PlausibleWeb.Endpoint,
      {Oban, Application.get_env(:plausible, Oban)}
    ]

    opts = [strategy: :one_for_one, name: Plausible.Supervisor]
    setup_sentry()
    setup_cache_stats()
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

  defp setup_cache_stats() do
    conf = Application.get_env(:plausible, :user_agent_cache)

    if conf[:stats] do
      :timer.apply_interval(1000 * 10, Plausible.Application, :report_cache_stats, [])
    end
  end

  def setup_sentry() do
    Logger.add_backend(Sentry.LoggerBackend)

    :telemetry.attach_many(
      "oban-errors",
      [[:oban, :job, :exception], [:oban, :notifier, :exception], [:oban, :plugin, :exception]],
      &ErrorReporter.handle_event/4,
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
