defmodule Plausible.Repo.Migrations.AddFirstAndLastToFunnels do
  use Ecto.Migration

  def change do
    alter table(:funnels) do
      add :first_and_last, :boolean, null: false, default: false
    end
  end
end
