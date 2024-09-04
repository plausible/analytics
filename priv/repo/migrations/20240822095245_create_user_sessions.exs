defmodule Plausible.Repo.Migrations.CreateUserSessions do
  use Ecto.Migration

  def change do
    create table(:user_sessions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :device, :string, null: false
      add :last_used_at, :naive_datetime, null: false
      add :timeout_at, :naive_datetime, null: false

      timestamps(updated_at: false)
    end

    create index(:user_sessions, [:user_id])
    create index(:user_sessions, [:timeout_at])
    create unique_index(:user_sessions, [:token])
  end
end
