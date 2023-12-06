defmodule Plausible.Repo.Migrations.AddTotpUserFieldsAndRecoveryCodes do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :totp_secret, :binary
      add :totp_enabled, :boolean, null: false, default: false
      add :totp_last_used_at, :naive_datetime
    end

    create table(:totp_recovery_codes) do
      add :code_digest, :binary, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      timestamps(updated_at: false)
    end

    create index(:totp_recovery_codes, [:user_id])
  end
end
