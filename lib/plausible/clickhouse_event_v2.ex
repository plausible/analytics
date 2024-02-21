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

    # Fields which are in the schema but not managed by us anymore.
    field :session_referrer, :string, virtual: true
    field :session_referrer_source, :string, virtual: true
    field :session_utm_medium, :string, virtual: true
    field :session_utm_source, :string, virtual: true
    field :session_utm_campaign, :string, virtual: true
    field :session_utm_content, :string, virtual: true
    field :session_utm_term, :string, virtual: true

    field :session_country_code, Ch, type: "FixedString(2)", virtual: true
    field :session_subdivision1_code, Ch, type: "LowCardinality(String)", virtual: true
    field :session_subdivision2_code, Ch, type: "LowCardinality(String)", virtual: true
    field :session_city_geoname_id, Ch, type: "UInt32", virtual: true

    field :session_screen_size, Ch, type: "LowCardinality(String)", virtual: true
    field :session_operating_system, Ch, type: "LowCardinality(String)", virtual: true
    field :session_operating_system_version, Ch, type: "LowCardinality(String)", virtual: true
    field :session_browser, Ch, type: "LowCardinality(String)", virtual: true
    field :session_browser_version, Ch, type: "LowCardinality(String)", virtual: true
    # field :transferred_from, :string
  end

  @required_keys [:name, :site_id, :hostname, :pathname, :user_id, :timestamp]
  @optional_keys [
    :"meta.key",
    :"meta.value",
    :revenue_source_amount,
    :revenue_source_currency,
    :revenue_reporting_amount,
    :revenue_reporting_currency,
    :session_operating_system,
    :session_operating_system_version,
    :session_browser,
    :session_browser_version,
    :session_referrer,
    :session_referrer_source,
    :session_utm_medium,
    :session_utm_source,
    :session_utm_campaign,
    :session_utm_content,
    :session_utm_term,
    :session_country_code,
    :session_subdivision1_code,
    :session_subdivision2_code,
    :session_city_geoname_id,
    :session_screen_size
  ]
  @all_keys @required_keys ++ @optional_keys

  def update(event, attrs) do
    cast(event, attrs, @all_keys)
  end

  def validate(event) do
    validate_required(event, @required_keys)
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
