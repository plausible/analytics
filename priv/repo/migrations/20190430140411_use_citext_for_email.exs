defmodule Plausible.Repo.Migrations.UseCitextForEmail do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext;"

    alter table(:users) do
      modify :email, :citext, null: false
    end
  end
end
