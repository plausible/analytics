defmodule Plausible.Ingestion.Counters.Buffer do
  @moduledoc """
  A buffer aggregating internal counters within spiralling buckets
  (resetting every minute) per domain and metric.

  Aggregates can be flushed on demand. Current bucket is excluded from
  flush until its time has passed.
  """

  defstruct [:buffer_name, :bucket_fn]

  alias Plausible.Ingestion.Counters.Record

  @type t() :: %__MODULE__{}
  @type unix_timestamp() :: pos_integer()
  @type bucket_fn_opt() :: {:bucket_fn, (DateTime.t() -> unix_timestamp())}

  @ets_opts [
    :public,
    :ordered_set,
    :named_table,
    write_concurrency: true
  ]

  @spec new(atom(), [bucket_fn_opt()]) :: t()
  def new(buffer_name, opts \\ []) do
    ^buffer_name = :ets.new(buffer_name, @ets_opts)

    bucket_fn = Keyword.get(opts, :bucket_fn, &minute_spiral/1)

    %__MODULE__{
      buffer_name: buffer_name,
      bucket_fn: bucket_fn
    }
  end

  @spec aggregate(t(), binary(), binary(), now :: DateTime.t()) :: t()
  def aggregate(
        %__MODULE__{buffer_name: buffer_name, bucket_fn: bucket_fn} = buffer,
        metric,
        domain,
        now \\ DateTime.utc_now()
      ) do
    bucket = bucket_fn.(now)

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
        %__MODULE__{buffer_name: buffer_name, bucket_fn: bucket_fn},
        now \\ DateTime.utc_now()
      ) do
    match = {{:"$1", :"$2", :"$3"}, :"$4"}
    guard = {:<, :"$1", bucket_fn.(now)}
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

  @spec minute_spiral(DateTime.t()) :: unix_timestamp()
  def minute_spiral(now) do
    now
    |> DateTime.truncate(:second)
    |> Map.replace(:second, 0)
    |> DateTime.to_unix()
  end
end
