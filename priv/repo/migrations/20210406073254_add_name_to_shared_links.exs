defmodule Plausible.Repo.Migrations.AddNameToSharedLinks do
  use Ecto.Migration

  def change do
    alter table(:shared_links) do
      add :name, :string
    end

    execute "UPDATE shared_links SET name=slug"

    alter table(:shared_links) do
      modify :name, :string, null: false
    end
  end
end
