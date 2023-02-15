defmodule Plausible.Ingestion.Counters.Record do
  @moduledoc """
  Clickhouse schema for storing ingest counter metrics
  """
  use Ecto.Schema

  @type t() :: %__MODULE__{}

  @primary_key false
  schema "ingest_counters" do
    field :event_timebucket, :utc_datetime
    field :application, :string
    #  XXX: store site identifier too?
    field :domain, :string
    field :metric, :string
    field :value, :integer
  end
end
