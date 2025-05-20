defmodule Plausible.Repo.Migrations.RemoveUnusedTablesAndColumns do
  use Ecto.Migration

  import Plausible.MigrationUtils

  def up do
    if enterprise_edition?() do
      alter table(:users) do
        remove :accept_traffic_until
        remove :trial_expiry_date
        remove :grace_period
        remove :allow_next_upgrade_override
      end

      alter table(:sites) do
        remove :accept_traffic_until
      end

      alter table(:api_keys) do
        remove :hourly_request_limit
      end

      drop constraint(:subscriptions, "subscriptions_user_id_fkey")
      drop constraint(:subscriptions, "subscriptions_team_id_fkey")

      alter table(:subscriptions) do
        remove :user_id
        modify :team_id, references(:teams, on_delete: :delete_all), null: false
      end

      drop constraint(:enterprise_plans, "enterprise_plans_user_id_fkey")
      drop constraint(:enterprise_plans, "enterprise_plans_team_id_fkey")

      alter table(:enterprise_plans) do
        remove :user_id
        modify :team_id, references(:teams, on_delete: :delete_all), null: false
      end

      drop table(:invitations)
      drop table(:site_memberships)
    end
  end

  def down do
    raise "Irreversible"
  end
end
