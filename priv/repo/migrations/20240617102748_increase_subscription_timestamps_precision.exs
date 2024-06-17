defmodule Plausible.Repo.Migrations.IncreaseSubscriptionTimestampsPrecision do
  use Ecto.Migration

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
