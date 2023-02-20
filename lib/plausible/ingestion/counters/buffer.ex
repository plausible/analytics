defmodule Plausible.Ingestion.Counters.Buffer do
  @moduledoc """
  A buffer aggregating internal counters within spiralling buckets.

  Aggregates are placed in buckets resetting every 1 minute.
  Flushing is done using 10 seconds moving window.

  Aggregates can be flushed on demand. Current bucket is excluded from
  flush until its time has passed.
  """

  defstruct [:buffer_name, :aggregate_bucket_fn]

  alias Plausible.Ingestion.Counters.Record

  @type t() :: %__MODULE__{}
  @type unix_timestamp() :: pos_integer()
  @type bucket_fn_opt() ::
          {:aggregate_bucket_fn, (NaiveDateTime.t() -> unix_timestamp())}

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

    %__MODULE__{
      buffer_name: buffer_name,
      aggregate_bucket_fn: aggregate_bucket_fn
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
      |> IO.inspect(label: :bucket)

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
        %__MODULE__{buffer_name: buffer_name},
        now \\ DateTime.utc_now()
      ) do
    boundary =
      now |> DateTime.add(-10, :second) |> IO.inspect(label: :minus) |> DateTime.to_unix()

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
    |> IO.inspect(label: :input_dt)
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.truncate(:second)
    |> Map.replace(:second, div(datetime.second, 10) * 10)
    |> IO.inspect(label: :agg_bucket_dt)
    |> DateTime.to_unix()
    |> IO.inspect(label: :agg_bucket)
  end
end
