defmodule Plausible.Repo.Migrations.TrackAcceptTrafficUntilNotifcations do
  use Ecto.Migration

  def change do
    create table(:sent_accept_traffic_until_notifications) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :sent_on, :date, null: false
    end

    create unique_index(:sent_accept_traffic_until_notifications, [:user_id, :sent_on])
  end
end
