defmodule Plausible.Repo.Migrations.GracePeriodEnd do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :grace_period_end, :date
    end
  end
end
