defmodule Plausible.Repo.Migrations.CascadeGoogleAuthDeletion do
  use Ecto.Migration

  def change do
    drop constraint("google_auth", "google_auth_site_id_fkey")

    alter table(:google_auth) do
      modify :site_id, references(:sites, on_delete: :delete_all), null: false
    end
  end
end
