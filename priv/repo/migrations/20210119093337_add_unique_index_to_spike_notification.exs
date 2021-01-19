defmodule Plausible.Repo.Migrations.AddUniqueIndexToSpikeNotification do
  use Ecto.Migration

  def change do
    create unique_index(:spike_notifications, :site_id)
  end
end
