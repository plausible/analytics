defmodule Plausible.Repo.Migrations.CascadeSiteDeletionToSpikeNotification do
  use Ecto.Migration

  def change do
    drop constraint("spike_notifications", "spike_notifications_site_id_fkey")

    alter table(:spike_notifications) do
      modify :site_id, references(:sites, on_delete: :delete_all), null: false
    end
  end
end
