defmodule Plausible.Repo.Migrations.CascadeDeleteEnterprisePlans do
  use Ecto.Migration

  def change do
    drop(constraint(:enterprise_plans, "enterprise_plans_user_id_fkey"))

    alter table(:enterprise_plans) do
      modify(:user_id, references(:users, on_delete: :delete_all), null: false)
    end
  end
end
