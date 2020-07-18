defmodule Plausible.Repo.Migrations.CreateSaltsTable do
  use Ecto.Migration

  def change do
    create table(:salts) do
      add :salt, :bytea, null: false

      timestamps(updated_at: false)
    end
  end
end
