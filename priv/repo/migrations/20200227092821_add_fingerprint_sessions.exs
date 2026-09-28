defmodule Plausible.Repo.Migrations.AddFingerprintSessions do
  use Ecto.Migration

  def change do
    create table(:fingerprint_sessions) do
      add :hostname, :text, null: false
      add :domain, :text, null: false
      add :fingerprint, :string, size: 64, null: false

      add :is_bounce, :boolean, null: false
      add :length, :integer

      add :referrer, :string
      add :referrer_source, :string
      add :country_code, :string
      add :screen_size, :string
      add :operating_system, :string
      add :browser, :string
      add :exit_page, :text
      add :entry_page, :text, null: false
      add :start, :naive_datetime, null: false

      timestamps(inserted_at: :timestamp, updated_at: false)
    end
  end
end
