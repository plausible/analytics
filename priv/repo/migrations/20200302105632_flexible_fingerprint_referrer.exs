defmodule Plausible.Repo.Migrations.FlexibleFingerprintReferrer do
  use Ecto.Migration

  def change do
    alter table(:fingerprint_sessions) do
      modify :referrer, :text
    end
  end
end
