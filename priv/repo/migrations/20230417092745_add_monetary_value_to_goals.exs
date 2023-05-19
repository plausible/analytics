defmodule Plausible.Repo.Migrations.AddMonetaryValueToGoals do
  use Ecto.Migration

  def change do
    alter table(:goals) do
      add :currency, :string
    end
  end
end
