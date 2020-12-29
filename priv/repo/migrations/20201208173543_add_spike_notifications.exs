defmodule Plausible.Repo.Migrations.AddSpikeNotifications do
  use Ecto.Migration

  def change do
    create table(:spike_notifications) do
      add :site_id, references(:sites), null: false
      add :threshold, :integer, null: false
      add :last_sent, :naive_datetime
      add :recipients, {:array, :citext}, null: false, default: []

      timestamps()
    end
  end
end
