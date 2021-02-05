defmodule Plausible.Repo.Migrations.CreateApiKeys do
  use Ecto.Migration

  def change do
    create table(:api_keys) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :key_prefix, :string, null: false
      add :key_hash, :string, null: false

      timestamps()
    end
  end
end
