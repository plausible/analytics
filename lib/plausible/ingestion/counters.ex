defmodule Plausible.Ingestion.Counters do
  @moduledoc """
  This is instrumentation necessary for keeping track of per-domain
  internal metrics. Due to metric labels cardinatlity (domain x metric_name),
  these statistics are not suitable for prometheus/grafana exposure,
  hence an internal storage is used.

  The module installs `Counters.TelemetryHandler` and periodicially
  flushes the internal counter aggregates via `Counters.Buffer` interface.
  """

  @behaviour :gen_cycle

  require Logger

  alias Plausible.Ingestion.Counters.Buffer
  alias Plausible.Ingestion.Counters.Record
  alias Plausible.Ingestion.Counters.TelemetryHandler
  alias Plausible.IngestRepo

  @interval :timer.seconds(10)

  @spec child_spec(Keyword.t()) :: Supervisor.child_spec() | :ignore
  def child_spec(opts) do
    buffer_name = Keyword.get(opts, :buffer_name, __MODULE__)

    %{
      id: buffer_name,
      start: {:gen_cycle, :start_link, [{:local, buffer_name}, __MODULE__, opts]}
    }
  end

  @spec enabled?() :: boolean()
  def enabled?() do
    Application.fetch_env!(:plausible, __MODULE__)[:enabled] == true
  end

  @impl true
  def init_cycle(opts) do
    buffer_name = Keyword.get(opts, :buffer_name, __MODULE__)
    force_start? = Keyword.get(opts, :force_start?, false)

    if enabled?() or force_start? do
      buffer = Buffer.new(buffer_name, opts)
      :ok = TelemetryHandler.install(buffer)

      interval = Keyword.get(opts, :interval, @interval)

      {:ok, {interval, buffer}}
    else
      :ignore
    end
  end

  @impl true
  def handle_cycle(buffer) do
    case Buffer.flush(buffer) do
      [] ->
        :noop

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

        try do
          # XXX: This must be changed to async_insert=1 clause
          # Trying to figure out how to do that with the current driver
          IngestRepo.checkout(fn ->
            IngestRepo.query!("SET async_insert = 1")
            {_, _} = IngestRepo.insert_all(Record, records)
            IngestRepo.query!("SET async_insert = 0")
          end)
        catch
          _, thrown ->
            Logger.error(
              "Caught an error when trying to flush ingest counters: #{inspect(thrown)}"
            )
        end
    end

    {:continue_hibernated, buffer}
  end

  @impl true
  def handle_info(_msg, state) do
    {:continue, state}
  end
end
