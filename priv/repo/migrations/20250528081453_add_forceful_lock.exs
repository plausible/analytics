defmodule Plausible.Repo.Migrations.AddForcefulLock do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add :locked_by_admin, :boolean, null: false, default: false
    end
  end
end
