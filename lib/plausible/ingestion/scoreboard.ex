defmodule Plausible.Ingestion.Scoreboard do
  @behaviour :gen_cycle

  @event_dropped Plausible.Ingestion.Event.telemetry_event_dropped()
  @event_buffered Plausible.Ingestion.Event.telemetry_event_buffered()

  @telemetry_events [@event_dropped, @event_buffered]
  @telemetry_handler &__MODULE__.handle_event/4
  @telemetry_handler_name "ingest-scoreboard"

  @dump_interval :timer.seconds(10)
  @bucket_fn &__MODULE__.current_bucket/0

  @ets_opts [
    :public,
    :ordered_set,
    :named_table,
    write_concurrency: true
  ]

  @spec child_spec(Keyword.t()) :: Supervisor.child_spec() | :ignore
  def child_spec(opts) do
    child_name = Keyword.get(opts, :child_name, __MODULE__)

    %{
      id: child_name,
      start: {:gen_cycle, :start_link, [{:local, child_name}, __MODULE__, opts]}
    }
  end

  @impl true
  def init_cycle(opts) do
    :ok = make_ets(opts)
    :ok = setup_telemetry(opts)

    interval = Keyword.get(opts, :interval, @dump_interval)
    {:ok, {interval, opts}}
  end

  @impl true
  def handle_cycle(opts) do
    IO.inspect(dump(), label: :dumplings)

    {:continue_hibernated, opts}
  end

  @impl true
  def handle_info(_msg, state) do
    {:continue, state}
  end

  def handle_event(@event_dropped, _measurements, %{domain: domain, reason: reason}, config) do
    save("dropped_#{reason}", domain, Map.fetch!(config, :bucket_fn))
  end

  def handle_event(@event_buffered, _measurements, %{domain: domain}, config) do
    save("buffered", domain, Map.fetch!(config, :bucket_fn))
  end

  def save(metric, domain, bucket_fn) do
    bucket = bucket_fn.()

    :ets.update_counter(
      __MODULE__,
      {bucket, metric, domain},
      {2, 1},
      {{bucket, metric, domain}, 0}
    )
  end

  def dump(bucket_fn \\ @bucket_fn) do
    match = {{:"$1", :"$2", :"$3"}, :"$4"}
    guard = {:<, :"$1", bucket_fn.()}
    select = {{:"$1", :"$2", :"$3", :"$4"}}

    match_specs = [
      {match, [guard], [select]}
    ]

    :ets.select(__MODULE__, match_specs)
  end

  def current_bucket() do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> Map.replace(:second, 0)
    |> DateTime.to_unix()
  end

  defp make_ets(opts) do
    name = Keyword.get(opts, :ets_table_name, __MODULE__)
    ^name = :ets.new(name, @ets_opts)
    :ok
  end

  defp setup_telemetry(opts) do
    bucket_fn = Keyword.get(opts, :bucket_fn, @bucket_fn)
    handler = Keyword.get(opts, :telemetry_handler, @telemetry_handler)
    handler_name = Keyword.get(opts, :telemetry_handler_name, @telemetry_handler_name)

    :ok =
      :telemetry.attach_many(handler_name, @telemetry_events, handler, %{
        bucket_fn: bucket_fn
      })
  end
end
