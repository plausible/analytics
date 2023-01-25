defmodule Plausible.Repo.Migrations.CascadeDeleteSentRenewalNotifications do
  use Ecto.Migration

  def change do
    drop constraint("sent_renewal_notifications", "sent_renewal_notifications_user_id_fkey")

    alter table(:sent_renewal_notifications) do
      modify :user_id, references(:users, on_delete: :delete_all), null: false
    end
  end
end
