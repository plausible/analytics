defmodule Plausible.Repo.Migrations.AddThemePrefToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :theme, :string
    end

    alter table(:users) do
      modify :theme, :string, null: false
    end
  end
end
