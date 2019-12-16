defmodule Plausible.Repo.Migrations.AddUniqueIndexToEmailReports do
  use Ecto.Migration
  use Plausible.Repo

  def change do
    create unique_index(:monthly_reports, :site_id)
  end
end
