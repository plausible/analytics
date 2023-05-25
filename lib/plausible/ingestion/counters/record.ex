defmodule Plausible.Ingestion.Counters.Record do
  @moduledoc """
  Clickhouse schema for storing ingest counter metrics
  """
  use Ecto.Schema

  @type t() :: %__MODULE__{}

  @primary_key false
  schema "ingest_counters" do
    field :event_timebucket, :utc_datetime
    field :site_id, Ch, type: "Nullable(UInt64)"
    field :domain, Ch, type: "LowCardinality(String)"
    field :metric, Ch, type: "LowCardinality(String)"
    field :value, Ch, type: "UInt64"
  end
end
