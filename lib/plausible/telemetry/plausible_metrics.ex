defmodule Plausible.PromEx.Plugins.PlausibleMetrics do
  @moduledoc """
  Custom PromEx plugin for instrumenting code within Plausible app.
  """
  use PromEx.Plugin

  @impl true
  def polling_metrics(opts) do
    poll_rate = Keyword.get(opts, :poll_rate, 5_000)
    otp_app = Keyword.fetch!(opts, :otp_app)

    metric_prefix =
      Keyword.get(opts, :metric_prefix, PromEx.metric_prefix(otp_app, :plausible_metrics))

    [
      write_buffer_metrics(metric_prefix, poll_rate),
      cache_metrics(metric_prefix, poll_rate)
    ]
  end

  @impl true
  def event_metrics(_opts) do
    metric_prefix = [:plausible, :profiling]

    Event.build(
      :plausible_event_metrics,
      [
        counter(
          metric_prefix ++ [:ingestion, :site, :lookup, :counter],
          event_name: [:plausible, :ingestion, :site, :lookup],
          measurement: fn _ -> 1 end,
          description: "Ingestion site lookup counter"
        ),
        distribution(
          metric_prefix ++ [:ingestion, :site, :lookup, :duration, :milliseconds],
          event_name: [:plausible, :ingestion, :site, :lookup],
          description: "Ingestion site lookup duration",
          measurement: :duration,
          reporter_options: [
            buckets: [5, 10, 50, 250, 1_000, 5_000]
          ],
          unit: {:native, :millisecond}
        )
      ]
    )
  end

  @doc """
  Add telemetry events for Session and Event write buffers
  """
  def execute_write_buffer_metrics do
    event_write_buffer_pid = GenServer.whereis(Plausible.Event.WriteBuffer)

    {:message_queue_len, events_message_queue_len} =
      if is_pid(event_write_buffer_pid),
        do: Process.info(event_write_buffer_pid, :message_queue_len),
        else: {:message_queue_len, 0}

    session_write_buffer_pid = GenServer.whereis(Plausible.Event.WriteBuffer)

    {:message_queue_len, sessions_message_queue_len} =
      if is_pid(session_write_buffer_pid),
        do: Process.info(session_write_buffer_pid, :message_queue_len),
        else: {:message_queue_len, 0}

    :telemetry.execute([:prom_ex, :plugin, :write_buffer_metrics, :events_message_queue_len], %{
      count: events_message_queue_len
    })

    :telemetry.execute([:prom_ex, :plugin, :write_buffer_metrics, :sessions_message_queue_len], %{
      count: sessions_message_queue_len
    })
  end

  @doc """
  Add telemetry events for Cachex user agents and sessions
  """
  def execute_cache_metrics do
    user_agents_count =
      case Cachex.stats(:user_agents) do
        # https://github.com/whitfin/cachex/pull/301
        {:ok, %{writes: w, evictions: e}} when is_integer(w) and is_integer(e) -> w - e
        _ -> 0
      end

    sessions_count =
      case Cachex.stats(:sessions) do
        # https://github.com/whitfin/cachex/pull/301
        {:ok, %{writes: w, evictions: e}} when is_integer(w) and is_integer(e) -> w - e
        _ -> 0
      end

    :telemetry.execute([:prom_ex, :plugin, :cachex, :user_agents_count], %{
      count: user_agents_count
    })

    :telemetry.execute([:prom_ex, :plugin, :cachex, :sessions_count], %{
      count: sessions_count
    })
  end

  defp write_buffer_metrics(metric_prefix, poll_rate) do
    Polling.build(
      :write_buffer_metrics,
      poll_rate,
      {__MODULE__, :execute_write_buffer_metrics, []},
      [
        last_value(
          metric_prefix ++ [:events, :message_queue_len, :count],
          event_name: [:prom_ex, :plugin, :write_buffer_metrics, :events_message_queue_len],
          measurement: :count
        ),
        last_value(
          metric_prefix ++ [:sessions, :message_queue_len, :count],
          event_name: [:prom_ex, :plugin, :write_buffer_metrics, :sessions_message_queue_len],
          measurement: :count
        )
      ]
    )
  end

  defp cache_metrics(metric_prefix, poll_rate) do
    Polling.build(
      :cache_metrics,
      poll_rate,
      {__MODULE__, :execute_cache_metrics, []},
      [
        last_value(
          metric_prefix ++ [:events, :cache_size, :count],
          event_name: [:prom_ex, :plugin, :cachex, :sessions_count],
          measurement: :count
        ),
        last_value(
          metric_prefix ++ [:sessions, :cache_size, :count],
          event_name: [:prom_ex, :plugin, :cachex, :user_agents_count],
          measurement: :count
        )
      ]
    )
  end
end
