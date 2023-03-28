defmodule Plausible.Repo.Migrations.AddSiteTransferColumns do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :transferred_from, :string, null: true
      add :transferred_at, :naive_datetime, null: true
    end

    create unique_index(:sites, :transferred_from)
  end
end
