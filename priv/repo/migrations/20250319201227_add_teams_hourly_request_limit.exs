defmodule Plausible.Repo.Migrations.AddTeamsHourlyRequestLimit do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add :hourly_request_limit, :integer, null: false, default: 600
    end
  end
end
