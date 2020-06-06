defmodule Plausible.Repo.Migrations.RemoveFingerprintSessionsTable do
  use Ecto.Migration

  def change do
    drop table(:fingerprint_sessions)
  end
end
