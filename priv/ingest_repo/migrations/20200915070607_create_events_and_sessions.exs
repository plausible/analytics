defmodule Plausible.ClickhouseRepo.Migrations.CreateEventsAndSessions do
  use Ecto.Migration

  def up do
    create_events()
    create_sessions()
  end

  defp create_events() do
    create_if_not_exists table(:events,
                           primary_key: false,
                           engine: "MergeTree",
                           options: [
                             partition_by: "toYYYYMM(timestamp)",
                             order_by: "(domain, toDate(timestamp), user_id)",
                             settings: "index_granularity = 8192"
                           ]
                         ) do
      add(:name, :string)
      add(:domain, :string)
      add(:user_id, :UInt64)
      add(:session_id, :UInt64)
      add(:hostname, :string)
      add(:pathname, :string)
      add(:referrer, :string)
      add(:referrer_source, :string)
      add(:country_code, :"LowCardinality(FixedString(2))")
      add(:screen_size, :"LowCardinality(String)")
      add(:operating_system, :"LowCardinality(String)")
      add(:browser, :"LowCardinality(String)")

      add(:timestamp, :naive_datetime)
    end
  end

  defp create_sessions() do
    create_if_not_exists table(:sessions,
                           primary_key: false,
                           engine: "CollapsingMergeTree(sign)",
                           options: [
                             partition_by: "toYYYYMM(start)",
                             order_by: "(domain, toDate(start), user_id, session_id)",
                             settings: "index_granularity = 8192"
                           ]
                         ) do
      add(:session_id, :UInt64)
      add(:sign, :Int8)
      add(:domain, :string)
      add(:user_id, :UInt64)
      add(:hostname, :string)
      add(:is_bounce, :UInt8)
      add(:entry_page, :string)
      add(:exit_page, :string)
      add(:pageviews, :integer)
      add(:events, :integer)
      add(:duration, :UInt32)
      add(:referrer, :string)
      add(:referrer_source, :string)
      add(:country_code, :"LowCardinality(FixedString(2))")
      add(:screen_size, :"LowCardinality(String)")
      add(:operating_system, :"LowCardinality(String)")
      add(:browser, :"LowCardinality(String)")

      add(:start, :naive_datetime)
      add(:timestamp, :naive_datetime)
    end
  end
end
