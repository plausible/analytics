defmodule Plausible.Repo.Migrations.AddStrictOrderToFunnels do
  use Ecto.Migration

  def change do
    alter table(:funnels) do
      add :strict_order, :boolean, null: false, default: false
    end
  end
end
