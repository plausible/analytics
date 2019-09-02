defmodule Plausible.Repo.Migrations.AssociateGoogleAuthWithSite do
  use Ecto.Migration

  def change do
    alter table(:google_auth) do
      add :site_id, references(:sites), null: false
    end

    drop unique_index(:google_auth, :user_id)
    create unique_index(:google_auth, :site_id)
  end
end
