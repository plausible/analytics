defmodule Plausible.Repo.Migrations.AddLimitsToEnterprisePlans do
  use Ecto.Migration

  def change do
    alter table(:enterprise_plans) do
      modify :hourly_api_request_limit, :integer, null: false
      modify :monthly_pageview_limit, :integer, null: false
      modify :site_limit, :integer, null: false
      add :team_member_limit, :integer, null: false, default: -1
      add :features, {:array, :string}, null: false, default: ["props", "stats_api"]
    end
  end
end
