defmodule Plausible.Repo.Migrations.AddLegacyFlagToSiteImports do
  use Ecto.Migration

  def change do
    alter table(:site_imports) do
      add :legacy, :boolean, null: false, default: true
    end
  end
end
