defmodule Plausible.Repo.Migrations.AddTeamsHourlyApiRequestLimit do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add :hourly_api_request_limit, :integer, null: false, default: 600
    end
  end
end
