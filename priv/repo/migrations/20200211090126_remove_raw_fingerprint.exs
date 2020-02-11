defmodule Plausible.Repo.Migrations.RemoveRawFingerprint do
  use Ecto.Migration

  def change do
    alter table(:events) do
      remove :raw_fingerprint
    end
  end
end
