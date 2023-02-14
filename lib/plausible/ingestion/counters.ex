defmodule Plausible.Ingestion.Counters do
  @behaviour :gen_cycle

  require Logger

  alias Plausible.Ingestion.Counters.Record

  @event_dropped Plausible.Ingestion.Event.telemetry_event_dropped()
  @event_buffered Plausible.Ingestion.Event.telemetry_event_buffered()

  @telemetry_events [@event_dropped, @event_buffered]
  @telemetry_handler &__MODULE__.handle_event/4
  @telemetry_handler_name "ingest-scoreboard"

  @dump_interval :timer.seconds(10)
  @bucket_fn &__MODULE__.minute_spiral/0

  @ets_name __MODULE__
  @repo Plausible.IngestRepo

  @ets_opts [
    :public,
    :ordered_set,
    :named_table,
    write_concurrency: true
  ]

  @spec child_spec(Keyword.t()) :: Supervisor.child_spec() | :ignore
  def child_spec(opts) do
    ets_name = Keyword.get(opts, :ets_name, __MODULE__)

    %{
      id: ets_name,
      start: {:gen_cycle, :start_link, [{:local, ets_name}, __MODULE__, opts]}
    }
  end

  def enabled?() do
    Application.fetch_env!(:plausible, __MODULE__)[:enabled] == true
  end

  @impl true
  def init_cycle(opts) do
    force_start? = Keyword.get(opts, :force_start?, false)

    opts = init_defaults(opts)

    if enabled?() or force_start? do
      :ok = make_ets(opts)
      :ok = setup_telemetry(opts)
      interval = Keyword.fetch!(opts, :interval)
      {:ok, {interval, opts}}
    else
      :ignore
    end
  end

  @impl true
  def handle_cycle(opts) do
    case dequeue_old_buckets(opts) do
      [] ->
        {:continue_hibernated, opts}

      records ->
        records =
          Enum.map(records, fn {bucket, metric, domain, value} ->
            %{
              event_timebucket: DateTime.from_unix!(bucket),
              application: to_string(node()),
              metric: metric,
              domain: domain,
              value: value
            }
          end)

        repo = Keyword.fetch!(opts, :repo)

        try do
          {_, _} = repo.insert_all(Record, records)
        catch
          _, thrown ->
            Logger.error(
              "Caught an error when trying to flush ingest counters: #{inspect(thrown)}"
            )
        end

        {:continue_hibernated, opts}
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:continue, state}
  end

  def handle_event(@event_dropped, _measurements, %{domain: domain, reason: reason}, opts) do
    aggregate("dropped_#{reason}", domain, opts)
  end

  def handle_event(@event_buffered, _measurements, %{domain: domain}, opts) do
    aggregate("buffered", domain, opts)
  end

  def aggregate(metric, domain, opts) do
    bucket = Keyword.fetch!(opts, :bucket_fn).()
    ets_name = Keyword.fetch!(opts, :ets_name)

    :ets.update_counter(
      ets_name,
      {bucket, metric, domain},
      {2, 1},
      {{bucket, metric, domain}, 0}
    )
  end

  def dequeue_old_buckets(opts) do
    bucket_fn = Keyword.fetch!(opts, :bucket_fn)
    ets_name = Keyword.fetch!(opts, :ets_name)

    match = {{:"$1", :"$2", :"$3"}, :"$4"}
    guard = {:<, :"$1", bucket_fn.()}
    select = {{:"$1", :"$2", :"$3", :"$4"}}

    match_specs_read = [{match, [guard], [select]}]
    match_specs_delete = [{match, [guard], [true]}]

    case :ets.select(ets_name, match_specs_read) do
      [] ->
        []

      data ->
        :ets.select_delete(ets_name, match_specs_delete)
        data
    end
  end

  def minute_spiral() do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> Map.replace(:second, 0)
    |> DateTime.to_unix()
  end

  defp make_ets(opts) do
    name = Keyword.fetch!(opts, :ets_name)
    ^name = :ets.new(name, @ets_opts)
    :ok
  end

  defp setup_telemetry(opts) do
    handler = Keyword.fetch!(opts, :telemetry_handler)
    handler_name = Keyword.fetch!(opts, :telemetry_handler_name)

    :ok = :telemetry.attach_many(handler_name, @telemetry_events, handler, opts)
  end

  defp init_defaults(opts) do
    opts
    |> Keyword.put_new(:bucket_fn, @bucket_fn)
    |> Keyword.put_new(:telemetry_handler, @telemetry_handler)
    |> Keyword.put_new(:telemetry_handler_name, @telemetry_handler_name)
    |> Keyword.put_new(:ets_name, @ets_name)
    |> Keyword.put_new(:interval, @dump_interval)
    |> Keyword.put_new(:repo, @repo)
  end
end
