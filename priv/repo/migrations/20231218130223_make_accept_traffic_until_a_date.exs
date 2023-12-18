defmodule Plausible.Repo.Migrations.MakeAcceptTrafficUntilADate do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      modify :accept_traffic_until, :date
    end
  end
end
