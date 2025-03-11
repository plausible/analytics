defmodule Plausible.IngestRepo.Migrations.ImportedPagesTotalTimeOnPage do
  use Ecto.Migration

  def change do
    alter table(:imported_pages) do
      add :total_time_on_page, :UInt64
      add :total_time_on_page_visits, :UInt64
    end
  end
end
