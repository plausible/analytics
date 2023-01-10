defmodule Plausible.Repo.Migrations.IndexUpdatedAtForSites do
  use Ecto.Migration

  def change do
    create index(:sites, :updated_at)
  end
end
