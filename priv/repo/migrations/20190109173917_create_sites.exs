defmodule Plausible.Repo.Migrations.CreateSites do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false

      timestamps()
    end

    create unique_index(:users, :email)

    create table(:sites) do
      add :domain, :string, null: false

      timestamps()
    end

    create unique_index(:sites, :domain)

    create table(:site_memberships) do
      add :site_id, references(:sites), null: false
      add :user_id, references(:users), null: false

      timestamps()
    end

    create unique_index(:site_memberships, [:site_id, :user_id])
  end
end
