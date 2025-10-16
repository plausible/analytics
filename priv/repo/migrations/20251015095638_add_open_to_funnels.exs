defmodule Plausible.Repo.Migrations.AddOpenToFunnels do
  use Ecto.Migration

  def change do
    alter table(:funnels) do
      add :open, :boolean, null: false, default: false
    end
  end
end
