defmodule Plausible.Ingestion.Counters.Record do
  @moduledoc """
  Clickhouse schema for storing ingest counter metrics
  """
  use Ecto.Schema

  @type t() :: %__MODULE__{}

  @primary_key false
  schema "ingest_counters" do
    field :event_timebucket, :utc_datetime
    field :site_id, Ch.Types.Nullable, type: Ch.Types.UInt64
    field :domain, :string
    field :metric, :string
    field :value, Ch.Types.UInt64
  end
end
