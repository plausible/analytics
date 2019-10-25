defmodule Plausible.Repo.Migrations.AddUidToPageviews do
  use Ecto.Migration
  use Plausible.Repo

  def change do
    alter table(:pageviews) do
      add :user_id, :binary_id, null: false
    end
  end
end
