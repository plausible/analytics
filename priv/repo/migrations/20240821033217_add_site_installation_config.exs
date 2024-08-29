defmodule Plausible.Repo.Migrations.AddSiteInstallationConfig do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :installation_meta, :map
    end
  end
end
