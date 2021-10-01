defmodule Plausible.Repo.Migrations.AddRoleToSiteMemberships do
  use Ecto.Migration

  def change do
    create_query = "CREATE TYPE site_membership_role AS ENUM ('owner', 'admin', 'viewer')"
    drop_query = "DROP TYPE site_membership_role"
    execute(create_query, drop_query)

    alter table(:site_memberships) do
      add :role, :site_membership_role, null: false, default: "owner"
    end
  end
end
