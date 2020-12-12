defmodule Plausible.Repo.Migrations.AddTrialExpiryToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :theme, :string
    end

    execute("UPDATE users SET theme='system'")

    alter table(:users) do
      modify :theme, :string, null: false
    end
  end
end
