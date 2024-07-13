defmodule Plausible.Repo.Migrations.TrafficDropNotifications do
  use Ecto.Migration

  def change do
    drop index(:spike_notifications, [:site_id])

    alter table(:spike_notifications) do
      add :type, :string, default: "spike"
    end

    create unique_index(:spike_notifications, [:site_id, :type])
  end
end
