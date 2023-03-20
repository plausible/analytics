defmodule Plausible.Repo.Migrations.AddPublicSites do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :public, :boolean, null: false, default: false
    end
  end
end
