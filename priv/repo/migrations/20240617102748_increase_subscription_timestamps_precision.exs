defmodule Plausible.Repo.Migrations.IncreaseSubscriptionTimestampsPrecision do
  use Ecto.Migration
  
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    alter table(:subscriptions) do
      modify :inserted_at, :naive_datetime_usec
      modify :updated_at, :naive_datetime_usec
    end
  end

  def down do
    alter table(:subscriptions) do
      modify :inserted_at, :naive_datetime
      modify :updated_at, :naive_datetime
    end
  end
end
