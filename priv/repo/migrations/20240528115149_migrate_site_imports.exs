defmodule Plausible.Repo.Migrations.MigrateSiteImports do
  use Plausible
  use Ecto.Migration

  def up do
    if ce?() do
      Plausible.DataMigration.SiteImports.run()
    end
  end
end
