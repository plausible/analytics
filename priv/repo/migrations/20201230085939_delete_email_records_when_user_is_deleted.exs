defmodule Plausible.Repo.Migrations.DeleteEmailRecordsWhenUserIsDeleted do
  use Ecto.Migration

  def change do
    alter table(:create_site_emails) do
      modify :user_id, references(:users, on_delete: :delete_all),
        null: false,
        from: references(:users)
    end

    alter table(:check_stats_emails) do
      modify :user_id, references(:users, on_delete: :delete_all),
        null: false,
        from: references(:users)
    end
  end
end
