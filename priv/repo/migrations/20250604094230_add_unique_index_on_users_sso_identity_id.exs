defmodule Plausible.Repo.Migrations.AddUniqueIndexOnUsersSsoIdentityId do
  use Ecto.Migration

  import Plausible.MigrationUtils

  def change do
    if enterprise_edition?() do
      create_if_not_exists unique_index(:users, [:sso_identity_id])
    end
  end
end
