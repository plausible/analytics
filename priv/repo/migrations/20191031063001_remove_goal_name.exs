defmodule Plausible.Repo.Migrations.RemoveGoalName do
  use Ecto.Migration

  def change do
    alter table(:goals) do
      remove :name
    end
  end
end
