defmodule Plausible.Repo.Migrations.AddUniqueIndexToApiKeys do
  use Ecto.Migration

  def change do
    create unique_index(:api_keys, :key_hash)
  end
end
