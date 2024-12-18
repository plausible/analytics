defmodule Plausible.Ingestion.Counters.Buffer do
  @moduledoc """
  A buffer aggregating counters for internal metrics, within 10 seconds time buckets.

  See `Plausible.Ingestion.Counters` for integration.

  Flushing is by default possible only once the 10s bucket is complete
  (its window has moved). This is to avoid race conditions 
  when clearing up the buffer on dequeue - because there is no atomic "get and delete",
  and items are buffered concurrently, there is a gap between get and delete
  in which items written may disappear otherwise.

  `aggregate_bucket_fn` and `flush_boundary_fn` control that semantics and
  are configurable only for test purposes.
  """

  defstruct [:buffer_name, :aggregate_bucket_fn, :flush_boundary_fn]

  alias Plausible.Ingestion.Counters.Record

  @type t() :: %__MODULE__{}
  @type unix_timestamp() :: pos_integer()
  @type bucket_fn_opt() ::
          {:aggregate_bucket_fn, (NaiveDateTime.t() -> unix_timestamp())}
          | {:flush_boundary_fn, (DateTime.t() -> unix_timestamp())}

  @ets_opts [
    :public,
    :ordered_set,
    :named_table,
    write_concurrency: true
  ]

  @spec new(atom(), [bucket_fn_opt()]) :: t()
  def new(buffer_name, opts \\ []) do
    ^buffer_name = :ets.new(buffer_name, @ets_opts)

    aggregate_bucket_fn = Keyword.get(opts, :aggregate_bucket_fn, &bucket_10s/1)
    flush_boundary_fn = Keyword.get(opts, :flush_boundary_fn, &previous_10s/1)

    %__MODULE__{
      buffer_name: buffer_name,
      aggregate_bucket_fn: aggregate_bucket_fn,
      flush_boundary_fn: flush_boundary_fn
    }
  end

  @spec aggregate(t(), binary(), binary(), timestamp :: NaiveDateTime.t()) :: t()
  def aggregate(
        %__MODULE__{buffer_name: buffer_name, aggregate_bucket_fn: bucket_fn} = buffer,
        metric,
        domain,
        timestamp
      ) do
    bucket =
      bucket_fn.(timestamp)

    :ets.update_counter(
      buffer_name,
      {bucket, metric, domain},
      {2, 1},
      {{bucket, metric, domain}, 0}
    )

    buffer
  end

  @spec flush(t(), now :: DateTime.t()) :: [Record.t()]
  def flush(
        %__MODULE__{buffer_name: buffer_name, flush_boundary_fn: flush_boundary_fn},
        now \\ DateTime.utc_now()
      ) do
    boundary = flush_boundary_fn.(now)

    match = {{:"$1", :"$2", :"$3"}, :"$4"}
    guard = {:"=<", :"$1", boundary}
    select = {{:"$1", :"$2", :"$3", :"$4"}}

    match_specs_read = [{match, [guard], [select]}]
    match_specs_delete = [{match, [guard], [true]}]

    case :ets.select(buffer_name, match_specs_read) do
      [] ->
        []

      data ->
        :ets.select_delete(buffer_name, match_specs_delete)
        data
    end
  end

  @spec bucket_10s(NaiveDateTime.t()) :: unix_timestamp()
  def bucket_10s(datetime) do
    datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.truncate(:second)
    |> Map.replace(:second, div(datetime.second, 10) * 10)
    |> DateTime.to_unix()
  end

  @spec previous_10s(DateTime.t()) :: unix_timestamp()
  def previous_10s(datetime) do
    datetime
    |> DateTime.add(-10, :second)
    |> DateTime.to_unix()
  end
end
