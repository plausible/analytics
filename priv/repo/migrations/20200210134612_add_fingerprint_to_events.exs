defmodule Plausible.Repo.Migrations.AddFingerprintToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :fingerprint, :string, size: 64
    end
  end
end
