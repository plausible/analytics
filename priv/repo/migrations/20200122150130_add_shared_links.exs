defmodule Plausible.Repo.Migrations.AddSharedLinks do
  use Ecto.Migration

  def change do
    create table(:shared_links) do
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :slug, :string, null: false
      add :password_hash, :string

      timestamps()
    end
  end
end
