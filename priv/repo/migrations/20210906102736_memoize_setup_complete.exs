defmodule Plausible.Repo.Migrations.MemoizeSetupComplete do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :has_stats, :boolean, null: false, default: false
    end
  end
end
