defmodule Plausible.Repo.Migrations.AddSentRenewalNotifications do
  use Ecto.Migration

  def change do
    create table(:sent_renewal_notifications) do
      add :user_id, references(:users), null: false, on_delete: :delete_all
      add :timestamp, :naive_datetime
    end
  end
end
