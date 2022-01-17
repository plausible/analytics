defmodule Plausible.ClickhouseRepo.Migrations.AddCollapsingMergetreeEventsTable do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:events_v2,
                           engine:
                             "CollapsingMergeTree(sign) PARTITION BY toYYYYMM(timestamp) ORDER BY (domain, toDate(timestamp), user_id, event_id) SAMPLE BY user_id SETTINGS index_granularity = 8192"
                         ) do
      add(:name, :string)
      add(:domain, :string)
      add(:user_id, :UInt64)
      add(:event_id, :UInt64)
      add(:session_id, :UInt64)
      add(:hostname, :string)
      add(:pathname, :string)
      add(:referrer, :string)
      add(:referrer_source, :string)
      add(:country_code, :"LowCardinality(FixedString(2))")
      add(:screen_size, :"LowCardinality(String)")
      add(:operating_system, :"LowCardinality(String)")
      add(:browser, :"LowCardinality(String)")

      add :utm_medium, :string
      add :utm_source, :string
      add :utm_campaign, :string

      add :meta, {:nested, {{:key, :string}, {:value, :string}}}

      add :browser_version, :"LowCardinality(String)"
      add :operating_system_version, :"LowCardinality(String)"

      add(:subdivision1_code, :"LowCardinality(String)")
      add(:subdivision2_code, :"LowCardinality(String)")
      add(:city_geoname_id, :UInt32)

      add :utm_content, :string
      add :utm_term, :string

      add(:duration, :UInt32)
      add(:sign, :Int8)

      add(:timestamp, :naive_datetime)
    end
  end

end
