defmodule Plausible.Repo.Migrations.AddEmbeddedToSites do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :embeddable, :boolean, null: false, default: false
    end
  end
end
