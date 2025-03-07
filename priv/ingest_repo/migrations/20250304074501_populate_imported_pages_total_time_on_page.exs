defmodule Plausible.IngestRepo.Migrations.PopulateImportedPagesTotalTimeOnPage do
  use Ecto.Migration

  def up do
    # Note: This only populates the new column for old GA4 imports.
    # Other imports didn't populate the `time_on_page` column.
    execute """
    ALTER TABLE imported_pages
    UPDATE
      total_time_on_page = time_on_page,
      total_time_on_page_visits = visits
    WHERE time_on_page > 0
    """
  end

  def down do
    raise "Irreversible"
  end
end
