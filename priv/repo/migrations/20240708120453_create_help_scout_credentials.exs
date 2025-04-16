defmodule Plausible.Repo.Migrations.CreateHelpscoutCredentials do
  use Plausible
  use Ecto.Migration

  import Plausible.MigrationUtils

  def change do
    if enterprise_edition?() do
      create table(:help_scout_credentials) do
        add :access_token, :binary, null: false

        timestamps()
      end
    end
  end
end
