defmodule Plausible.ClickhouseEventV2 do
  @moduledoc """
  Event schema for when NumericIDs migration is complete
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "events_v2" do
    field :name, Ch, type: "LowCardinality(String)"
    field :site_id, Ch, type: "UInt64"
    field :hostname, :string
    field :pathname, :string
    field :user_id, Ch, type: "UInt64"
    field :session_id, Ch, type: "UInt64"
    field :timestamp, :naive_datetime

    field :"meta.key", {:array, :string}
    field :"meta.value", {:array, :string}

    field :revenue_source_amount, Ch, type: "Nullable(Decimal64(3))"
    field :revenue_source_currency, Ch, type: "FixedString(3)"
    field :revenue_reporting_amount, Ch, type: "Nullable(Decimal64(3))"
    field :revenue_reporting_currency, Ch, type: "FixedString(3)"
  end

  def new(attrs) do
    %__MODULE__{}
    |> cast(
      attrs,
      [
        :name,
        :site_id,
        :hostname,
        :pathname,
        :user_id,
        :timestamp,
        :"meta.key",
        :"meta.value",
        :revenue_source_amount,
        :revenue_source_currency,
        :revenue_reporting_amount,
        :revenue_reporting_currency
      ]
    )
    |> validate_required([:name, :site_id, :hostname, :pathname, :user_id, :timestamp])
  end
end
