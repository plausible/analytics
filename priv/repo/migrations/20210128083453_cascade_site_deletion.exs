defmodule Plausible.Repo.Migrations.CascadeSiteDeletion do
  use Ecto.Migration

  def change do
    drop constraint("site_memberships", "site_memberships_site_id_fkey")

    alter table(:site_memberships) do
      modify :site_id, references(:sites, on_delete: :delete_all), null: false
    end
  end
end
