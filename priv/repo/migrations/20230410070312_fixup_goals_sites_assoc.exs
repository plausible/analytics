defmodule Plausible.Repo.Migrations.FixupGoalsSitesAssoc do
  use Ecto.Migration

  def change do
    alter table(:goals) do
      modify :site_id, references(:sites, on_delete: :delete_all), null: false
      remove :domain
    end
  end
end
