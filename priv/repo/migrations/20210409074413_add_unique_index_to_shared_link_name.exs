defmodule Plausible.Repo.Migrations.AddUniqueIndexToSharedLinkName do
  use Ecto.Migration

  def change do
    create unique_index(:shared_links, [:site_id, :name], name: :shared_links_site_id_name_index)
  end
end
