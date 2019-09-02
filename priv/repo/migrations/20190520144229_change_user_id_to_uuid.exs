defmodule Plausible.Repo.Migrations.ChangeUserIdToUuid do
  use Ecto.Migration

  def change do
    execute("DELETE from pageviews where user_id='123'")
    execute("UPDATE pageviews set user_id='de610e53-6ec6-4e33-be37-7adcc1bf13be' where user_id='dummy'")
    flush()
    execute("ALTER TABLE pageviews ALTER COLUMN user_id TYPE uuid USING user_id::uuid")
  end
end
