defmodule Plausible.Repo.Migrations.AddLabelToSiteImports do
  use Ecto.Migration

  def change do
    alter table(:site_imports) do
      add :label, :string
    end
  end
end
