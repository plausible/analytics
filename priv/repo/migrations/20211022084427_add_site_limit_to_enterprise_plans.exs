defmodule Plausible.Repo.Migrations.AddSiteLimitToEnterprisePlans do
  use Ecto.Migration
  use Plausible.Repo

  def change do
    alter table(:enterprise_plans) do
      add :site_limit, :integer
    end

    flush()

    Repo.update_all("enterprise_plans", set: [site_limit: 50])

    alter table(:enterprise_plans) do
      modify :site_limit, :integer, null: false
    end
  end
end
