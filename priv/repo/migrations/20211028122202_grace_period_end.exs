defmodule Plausible.Repo.Migrations.GracePeriodEnd do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :grace_period, :map
    end
  end
end
