defmodule Plausible.Repo.Migrations.AddUniqueIndexToApiKeys do
  use Ecto.Migration

  def change do
    create unique_index(:api_keys, [:user_id, :key_hash])
  end
end
