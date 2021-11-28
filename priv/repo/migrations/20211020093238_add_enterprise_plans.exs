defmodule Plausible.Repo.Migrations.AddEnterprisePlans do
  use Ecto.Migration

  def change do
    create_query = "CREATE TYPE billing_interval AS ENUM ('monthly', 'yearly')"
    drop_query = "DROP TYPE billing_interval"
    execute(create_query, drop_query)

    create table(:enterprise_plans) do
      add :user_id, references(:users), null: false, unique: true
      add :paddle_plan_id, :string, null: false
      add :billing_interval, :billing_interval, null: false
      add :monthly_pageview_limit, :integer, null: false
      add :hourly_api_request_limit, :integer, null: false

      timestamps()
    end
  end
end
