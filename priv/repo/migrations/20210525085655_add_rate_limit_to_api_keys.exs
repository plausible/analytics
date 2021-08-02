defmodule Plausible.Repo.Migrations.AddRateLimitToApiKeys do
  use Ecto.Migration

  def change do
    alter table(:api_keys) do
      add :hourly_request_limit, :integer, null: false, default: 1000
    end
  end
end
