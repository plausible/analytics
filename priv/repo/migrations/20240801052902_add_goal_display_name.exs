defmodule Plausible.Repo.Migrations.AddGoalDisplayName do
  use Ecto.Migration

  def change do
    alter table(:goals) do
      add :display_name, :text
    end
  end
end
