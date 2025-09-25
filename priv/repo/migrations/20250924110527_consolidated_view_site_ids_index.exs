defmodule Plausible.Repo.Migrations.ConsolidatedViewSiteIdsIndex do
  use Ecto.Migration

  def change do
    create index(:sites, [:team_id, :consolidated, :id])
  end
end
