defmodule Plausible.Repo.Migrations.AddUniqueIndexOnSiteMembershipsSiteIdWhenOwner do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists unique_index(:site_memberships, [:site_id],
                           where: "role = 'owner'",
                           concurrently: true
                         )
  end
end
