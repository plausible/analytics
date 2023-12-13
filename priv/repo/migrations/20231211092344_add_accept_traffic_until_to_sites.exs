defmodule Plausible.Repo.Migrations.AddAcceptTrafficUntilToSites do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :accept_traffic_until, :naive_datetime
    end
  end
end
