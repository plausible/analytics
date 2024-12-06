defmodule Plausible.ClickhouseRepo.Migrations.CreateImportedVisitors do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:imported_visitors,
                           primary_key: false,
                           engine: "MergeTree",
                           options: """
                           ORDER BY (site_id, date)
                           #{Plausible.MigrationUtils.table_settings_expr()}
                           """
                         ) do
      add(:site_id, :UInt64)
      add(:date, :date)
      add(:visitors, :UInt64)
      add(:pageviews, :UInt64)
      add(:bounces, :UInt64)
      add(:visits, :UInt64)
      add(:visit_duration, :UInt64)
    end

    create_if_not_exists table(:imported_sources,
                           primary_key: false,
                           engine: "MergeTree",
                           options: """
                           ORDER BY (site_id, date, source)
                           #{Plausible.MigrationUtils.table_settings_expr()}
                           """
                         ) do
      add(:site_id, :UInt64)
      add(:date, :date)
      add(:source, :string)
      add(:utm_medium, :string)
      add(:utm_campaign, :string)
      add(:utm_content, :string)
      add(:utm_term, :string)
      add(:visitors, :UInt64)
      add(:visits, :UInt64)
      add(:visit_duration, :UInt64)
      add(:bounces, :UInt32)
    end

    create_if_not_exists table(:imported_pages,
                           primary_key: false,
                           engine: "MergeTree",
                           options: """
                           ORDER BY (site_id, date, hostname, page)
                           #{Plausible.MigrationUtils.table_settings_expr()}
                           """
                         ) do
      add(:site_id, :UInt64)
      add(:date, :date)
      add(:hostname, :string)
      add(:page, :string)
      add(:visitors, :UInt64)
      add(:pageviews, :UInt64)
      add(:exits, :UInt64)
      add(:time_on_page, :UInt64)
    end

    create_if_not_exists table(:imported_entry_pages,
                           primary_key: false,
                           engine: "MergeTree",
                           options: """
                           ORDER BY (site_id, date, entry_page)
                           #{Plausible.MigrationUtils.table_settings_expr()}
                           """
                         ) do
      add(:site_id, :UInt64)
      add(:date, :date)
      add(:entry_page, :string)
      add(:visitors, :UInt64)
      add(:entrances, :UInt64)
      add(:visit_duration, :UInt64)
      add(:bounces, :UInt32)
    end

    create_if_not_exists table(:imported_exit_pages,
                           primary_key: false,
                           engine: "MergeTree",
                           options: """
                           ORDER BY (site_id, date, exit_page)
                           #{Plausible.MigrationUtils.table_settings_expr()}
                           """
                         ) do
      add(:site_id, :UInt64)
      add(:date, :date)
      add(:exit_page, :string)
      add(:visitors, :UInt64)
      add(:exits, :UInt64)
    end

    create_if_not_exists table(:imported_locations,
                           primary_key: false,
                           engine: "MergeTree",
                           options: """
                           ORDER BY (site_id, date, country, region, city)
                           #{Plausible.MigrationUtils.table_settings_expr()}
                           """
                         ) do
      add(:site_id, :UInt64)
      add(:date, :date)
      add(:country, :string)
      add(:region, :string)
      add(:city, :UInt64)
      add(:visitors, :UInt64)
      add(:visits, :UInt64)
      add(:visit_duration, :UInt64)
      add(:bounces, :UInt32)
    end

    create_if_not_exists table(:imported_devices,
                           primary_key: false,
                           engine: "MergeTree",
                           options: """
                           ORDER BY (site_id, date, device)
                           #{Plausible.MigrationUtils.table_settings_expr()}
                           """
                         ) do
      add(:site_id, :UInt64)
      add(:date, :date)
      add(:device, :string)
      add(:visitors, :UInt64)
      add(:visits, :UInt64)
      add(:visit_duration, :UInt64)
      add(:bounces, :UInt32)
    end

    create_if_not_exists table(:imported_browsers,
                           primary_key: false,
                           engine: "MergeTree",
                           options: """
                           ORDER BY (site_id, date, browser)
                           #{Plausible.MigrationUtils.table_settings_expr()}
                           """
                         ) do
      add(:site_id, :UInt64)
      add(:date, :date)
      add(:browser, :string)
      add(:visitors, :UInt64)
      add(:visits, :UInt64)
      add(:visit_duration, :UInt64)
      add(:bounces, :UInt32)
    end

    create_if_not_exists table(:imported_operating_systems,
                           primary_key: false,
                           engine: "MergeTree",
                           options: """
                           ORDER BY (site_id, date, operating_system)
                           #{Plausible.MigrationUtils.table_settings_expr()}
                           """
                         ) do
      add(:site_id, :UInt64)
      add(:date, :date)
      add(:operating_system, :string)
      add(:visitors, :UInt64)
      add(:visits, :UInt64)
      add(:visit_duration, :UInt64)
      add(:bounces, :UInt32)
    end
  end
end
