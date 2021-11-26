defmodule Plausible.ClickhouseSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "sessions" do
    field :hostname, :string
    field :domain, :string
    field :user_id, :integer
    field :session_id, :integer

    field :start, :naive_datetime
    field :duration, :integer
    field :is_bounce, :boolean
    field :entry_page, :string
    field :exit_page, :string
    field :pageviews, :integer
    field :events, :integer
    field :sign, :integer

    field :utm_medium, :string
    field :utm_source, :string
    field :utm_campaign, :string
    field :referrer, :string
    field :referrer_source, :string

    field :country_code, :string, default: ""
    field :subdivision1_code, :string, default: ""
    field :subdivision2_code, :string, default: ""
    field :city_geoname_id, :integer, default: 0

    field :screen_size, :string
    field :operating_system, :string
    field :operating_system_version, :string
    field :browser, :string
    field :browser_version, :string
    field :timestamp, :naive_datetime
  end

  def random_uint64() do
    :crypto.strong_rand_bytes(8) |> :binary.decode_unsigned()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :hostname,
      :domain,
      :entry_page,
      :exit_page,
      :fingerprint,
      :start,
      :length,
      :is_bounce,
      :operating_system,
      :operating_system_version,
      :browser_version,
      :referrer,
      :referrer_source,
      :utm_medium,
      :utm_source,
      :utm_campaign,
      :country_code,
      :country_geoname_id,
      :subdivision1_code,
      :subdivision2_code,
      :city_geoname_id,
      :screen_size
    ])
    |> validate_required([:hostname, :domain, :fingerprint, :is_bounce, :start])
  end
end
