defmodule Plausible.IngestRepo.Migrations.DropEventSessionColumns do
  use Ecto.Migration

  @dropped_columns [
    :referrer,
    :referrer_source,
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
    :browser_version,
    :transferred_from
  ]

  def change do
    alter table(:events_v2) do
      for column <- @dropped_columns do
        remove(column)
      end
    end
  end
end
