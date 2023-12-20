defmodule Plausible.Repo.Migrations.AddAcceptTrafficUntilToUser do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      remove :accept_traffic_until
    end

    alter table(:users) do
      add :accept_traffic_until, :date
    end
  end
end
