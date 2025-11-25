defmodule Plausible.Repo.Migrations.AddTeamsPolicyToCe do
  use Ecto.Migration

  import Plausible.MigrationUtils

  def change do
    if community_edition?() do
      alter table(:teams) do
        add :policy, :jsonb, null: false, default: "{}"
      end
    end
  end
end
