defmodule Plausible.Repo.Migrations.SetTeamsAllowNextUpgradeOverrideDefault do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    execute """
              ALTER TABLE teams ALTER COLUMN allow_next_upgrade_override SET DEFAULT false;
            """,
            """
              ALTER TABLE teams ALTER COLUMN allow_next_upgrade_override DROP DEFAULT
            """
  end
end
