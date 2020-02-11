defmodule Plausible.Repo.Migrations.AddRawFingerprint do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :raw_fingerprint, :text
    end
  end
end
