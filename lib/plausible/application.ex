defmodule Plausible.Application do
  @moduledoc false

  use Application

  require Logger

  def start(_type, _args) do
    children = [
      Plausible.Repo,
      Plausible.ClickhouseRepo,
      {Phoenix.PubSub, name: Plausible.PubSub},
      PlausibleWeb.Endpoint,
      Plausible.Event.WriteBuffer,
      Plausible.Session.WriteBuffer,
      Plausible.Session.Store,
      Plausible.Session.Salts,
      ReferrerBlocklist,
      {Oban, Application.get_env(:plausible, Oban)},
      {Cachex,
       Keyword.merge(Application.get_env(:plausible, :user_agent_cache), name: :user_agents)}
    ]

    opts = [strategy: :one_for_one, name: Plausible.Supervisor]
    setup_sentry()
    setup_cache_stats()
    Location.load_all()
    Application.put_env(:plausible, :server_start, Timex.now())
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
      [[:oban, :job, :exception], [:oban, :circuit, :trip]],
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
