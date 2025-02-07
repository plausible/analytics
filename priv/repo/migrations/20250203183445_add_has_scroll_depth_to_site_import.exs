defmodule Plausible.Repo.Migrations.AddHasScrollDepthToSiteImport do
  use Ecto.Migration

  def change do
    alter table(:site_imports) do
      add :has_scroll_depth, :boolean, null: false, default: false
    end
  end
end
