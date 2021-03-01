defmodule Plausible.Repo.Migrations.AddExternalCssToSites do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :external_css, :string, null: true
    end
  end
end
