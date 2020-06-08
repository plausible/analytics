defmodule Plausible.Repo.Migrations.DeleteFeedbackEmailsWhenUserIsDeleted do
  use Ecto.Migration

  def change do
    alter table(:feedback_emails) do
      modify :user_id, references(:users, on_delete: :delete_all),
        null: false,
        from: references(:users)
    end
  end
end
