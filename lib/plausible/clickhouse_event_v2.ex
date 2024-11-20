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
    field :scroll_depth, Ch, type: "UInt8"

    field :revenue_source_amount, Ch, type: "Nullable(Decimal64(3))"
    field :revenue_source_currency, Ch, type: "FixedString(3)"
    field :revenue_reporting_amount, Ch, type: "Nullable(Decimal64(3))"
    field :revenue_reporting_currency, Ch, type: "FixedString(3)"

    # Session attributes
    field :referrer, :string
    field :referrer_source, :string
    field :click_id_param, Ch, type: "LowCardinality(String)"
    field :utm_medium, :string
    field :utm_source, :string
    field :utm_campaign, :string
    field :utm_content, :string
    field :utm_term, :string

    field :country_code, Ch, type: "FixedString(2)"
    field :subdivision1_code, Ch, type: "LowCardinality(String)"
    field :subdivision2_code, Ch, type: "LowCardinality(String)"
    field :city_geoname_id, Ch, type: "UInt32"

    field :screen_size, Ch, type: "LowCardinality(String)"
    field :operating_system, Ch, type: "LowCardinality(String)"
    field :operating_system_version, Ch, type: "LowCardinality(String)"
    field :browser, Ch, type: "LowCardinality(String)"
    field :browser_version, Ch, type: "LowCardinality(String)"

    field :acquisition_channel, Ch, type: "LowCardinality(String)", writable: :never
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
        :scroll_depth,
        :revenue_source_amount,
        :revenue_source_currency,
        :revenue_reporting_amount,
        :revenue_reporting_currency
      ]
    )
    |> validate_required([:name, :site_id, :hostname, :pathname, :user_id, :timestamp])
  end

  @session_properties [
    :session_id,
    :referrer,
    :referrer_source,
    :click_id_param,
    :utm_medium,
    :utm_source,
    :utm_campaign,
    :utm_content,
    :utm_term,
    :country_code,
    :subdivision1_code,
    :subdivision2_code,
    :city_geoname_id,
    :screen_size,
    :operating_system,
    :operating_system_version,
    :browser,
    :browser_version
  ]

  def merge_session(%__MODULE__{} = event, session) do
    Map.merge(event, Map.take(session, @session_properties))
  end
end
