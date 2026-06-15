defmodule Plausible.Repo.Migrations.AddTotpSecretFallbackToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :totp_secret_fallback, :binary
    end
  end
end
