defmodule Plausible.Repo.Migrations.AddAllowNextUpgradeOverrideToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :allow_next_upgrade_override, :boolean, null: false, default: false
    end
  end
end
