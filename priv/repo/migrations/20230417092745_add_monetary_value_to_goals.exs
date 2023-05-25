defmodule Plausible.Repo.Migrations.AddMonetaryValueToGoals do
  use Ecto.Migration

  def change do
    alter table(:goals) do
      add :currency, :"varchar(3)"
    end
  end
end
