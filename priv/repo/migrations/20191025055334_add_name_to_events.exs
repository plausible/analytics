defmodule Plausible.Repo.Migrations.AddNameToEvents do
  use Ecto.Migration
  use Plausible.Repo

  def change do
    alter table(:events) do
      add :name, :string, null: false
    end
  end
end
