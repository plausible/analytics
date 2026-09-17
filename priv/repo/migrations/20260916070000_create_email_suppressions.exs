defmodule Plausible.Repo.Migrations.CreateEmailSuppressions do
  use Ecto.Migration

  def change do
    create table(:email_suppressions) do
      add :email, :citext, null: false
      add :reason, :string, null: false
      add :source, :string, null: false
      add :postmark_bounce_id, :bigint
      add :postmark_inactive, :boolean, null: false, default: false
      add :can_activate, :boolean, null: false, default: false
      add :details, :text
      add :reactivated_at, :naive_datetime
      add :reactivated_by_user_id, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:email_suppressions, [:email])
    create index(:email_suppressions, [:reason])
  end
end
