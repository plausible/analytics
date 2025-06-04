defmodule Plausible.PromEx.Plugins.PlausibleMetrics do
  @moduledoc """
  Custom PromEx plugin for instrumenting code within Plausible app.
  """
  use PromEx.Plugin
  alias Plausible.Site
  alias Plausible.Ingestion

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
  def event_metrics(opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)
    metric_prefix = Keyword.get(opts, :metric_prefix, PromEx.metric_prefix(otp_app, :plausible))

    Event.build(
      :plausible_internal_telemetry,
      [
        distribution(
          metric_prefix ++ [:cache_warmer, :sites, :refresh, :all],
          event_name: Site.Cache.telemetry_event_refresh(:all),
          reporter_options: [
            buckets: [500, 1000, 2000, 5000, 10_000]
          ],
          unit: {:native, :millisecond},
          measurement: :duration
        ),
        distribution(
          metric_prefix ++ [:cache_warmer, :sites, :refresh, :updated_recently],
          event_name: Site.Cache.telemetry_event_refresh(:updated_recently),
          reporter_options: [
            buckets: [500, 1000, 2000, 5000, 10_000]
          ],
          unit: {:native, :millisecond},
          measurement: :duration
        ),
        distribution(
          metric_prefix ++ [:ingest, :events, :pipeline, :steps],
          event_name: Ingestion.Event.telemetry_pipeline_step_duration(),
          reporter_options: [
            buckets: [10, 50, 100, 250, 350, 500, 1000, 5000, 10_000, 100_000, 500_000]
          ],
          unit: {:native, :microsecond},
          measurement: :duration,
          tags: [:step]
        ),
        distribution(
          metric_prefix ++ [:sessions, :cache, :register, :lock],
          event_name: Plausible.Session.CacheStore.lock_telemetry_event(),
          reporter_options: [
            buckets: [10, 50, 100, 250, 350, 500, 1000, 5000, 10_000, 100_000, 500_000]
          ],
          unit: {:native, :microsecond},
          measurement: :duration
        ),
        counter(
          metric_prefix ++ [:ingest, :events, :buffered, :total],
          event_name: Ingestion.Event.telemetry_event_buffered()
        ),
        counter(
          metric_prefix ++ [:ingest, :events, :dropped, :total],
          event_name: Ingestion.Event.telemetry_event_dropped(),
          tags: [:reason]
        ),
        counter(
          metric_prefix ++ [:ingest, :user_agent_parse, :timeout, :total],
          event_name: Ingestion.Event.telemetry_ua_parse_timeout()
        ),
        counter(
          metric_prefix ++ [:plausible_cache, :hit],
          event_name: ConCache.Operations.telemetry_hit(),
          tags: [:name],
          tag_values: &%{name: &1.cache.name}
        ),
        counter(
          metric_prefix ++ [:plausible_cache, :miss],
          event_name: ConCache.Operations.telemetry_miss(),
          tags: [:name],
          tag_values: &%{name: &1.cache.name}
        ),
        distribution(
          metric_prefix ++ [:sessions, :transfer, :duration],
          event_name: Plausible.Session.Transfer.telemetry_event(),
          reporter_options: [
            buckets: [
              100_000,
              250_000,
              500_000,
              750_000,
              1_000_000,
              2_500_000,
              5_000_000,
              7_500_000,
              10_000_000
            ]
          ],
          unit: {:native, :microsecond},
          measurement: :duration
        ),
        counter(
          metric_prefix ++ [:tracker_script, :request, :v2],
          event_name: PlausibleWeb.TrackerPlug.telemetry_event(:v2),
          tags: [:status],
          tag_values: &%{status: &1.status}
        ),
        counter(
          metric_prefix ++ [:tracker_script, :request, :legacy],
          event_name: PlausibleWeb.TrackerPlug.telemetry_event(:legacy),
          tags: [:status],
          tag_values: &%{status: &1.status}
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
  Fire telemetry events for various caches
  """
  def execute_cache_metrics do
    :telemetry.execute([:prom_ex, :plugin, :cache, :user_agents], %{
      count: Plausible.Cache.Adapter.size(:user_agents)
    })

    :telemetry.execute([:prom_ex, :plugin, :cache, :sessions], %{
      count: Plausible.Cache.Adapter.size(:sessions)
    })

    :telemetry.execute([:prom_ex, :plugin, :cache, :sites], %{
      count: Site.Cache.size()
    })
  end

  def measure_duration(event, fun, meta \\ %{}) when is_function(fun, 0) do
    {duration, result} = time_it(fun)
    :telemetry.execute(event, %{duration: duration}, meta)
    result
  end

  defp time_it(fun) do
    start = System.monotonic_time()
    result = fun.()
    stop = System.monotonic_time()
    {stop - start, result}
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
          metric_prefix ++ [:cache, :sessions, :size],
          event_name: [:prom_ex, :plugin, :cache, :sessions],
          measurement: :count
        ),
        last_value(
          metric_prefix ++ [:cache, :user_agents, :size],
          event_name: [:prom_ex, :plugin, :cache, :user_agents],
          measurement: :count
        ),
        last_value(
          metric_prefix ++ [:cache, :sites, :size],
          event_name: [:prom_ex, :plugin, :cache, :sites],
          measurement: :count
        )
      ]
    )
  end
end
