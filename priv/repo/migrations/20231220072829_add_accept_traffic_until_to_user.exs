defmodule Plausible.Repo.Migrations.AddAcceptTrafficUntilToUser do
  use Ecto.Migration

  def change do
    # deleting accept_traffic_until from sites table will come later, not to crash anything live right now
    alter table(:users) do
      add :accept_traffic_until, :date
    end
  end
end
