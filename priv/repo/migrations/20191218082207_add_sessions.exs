defmodule Plausible.Repo.Migrations.AddSessions do
  use Ecto.Migration

  def change do
    create table(:sessions) do
      add :hostname, :text, null: false
      add :new_visitor, :boolean, null: false
      add :user_id, :binary_id, null: false

      add :is_bounce, :boolean, null: false
      add :length, :integer

      add :referrer, :string
      add :referrer_source, :string
      add :country_code, :string
      add :screen_size, :string
      add :operating_system, :string
      add :browser, :string

      timestamps(inserted_at: :timestamp, updated_at: false)
    end
  end
end
