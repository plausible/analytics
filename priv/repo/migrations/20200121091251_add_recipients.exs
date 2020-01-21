defmodule Plausible.Repo.Migrations.AddRecipients do
  use Ecto.Migration

  def up do
    alter table(:weekly_reports) do
      add :recipients, {:array, :citext}, null: false, default: []
    end

    execute "UPDATE weekly_reports SET recipients = array_append(recipients, email)"

    alter table(:weekly_reports) do
      remove :email
    end

    alter table(:monthly_reports) do
      add :recipients, {:array, :citext}, null: false, default: []
    end

    execute "UPDATE monthly_reports SET recipients = array_append(recipients, email)"

    alter table(:monthly_reports) do
      remove :email
    end
  end

  def down do
  end
end
