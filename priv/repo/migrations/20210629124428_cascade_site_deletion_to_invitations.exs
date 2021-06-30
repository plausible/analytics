defmodule Plausible.Repo.Migrations.CascadeSiteDeletionToInvitations do
  use Ecto.Migration

  def change do
    drop constraint("invitations", "invitations_site_id_fkey")

    alter table(:invitations) do
      modify :site_id, references(:sites, on_delete: :delete_all), null: false
    end
  end
end
