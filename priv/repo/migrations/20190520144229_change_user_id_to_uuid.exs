defmodule Plausible.Repo.Migrations.ChangeUserIdToUuid do
  use Ecto.Migration

  def change do
    execute("ALTER TABLE pageviews ALTER COLUMN user_id TYPE uuid USING user_id::uuid")
  end
end
