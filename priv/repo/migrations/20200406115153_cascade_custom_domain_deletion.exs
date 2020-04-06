defmodule Plausible.Repo.Migrations.CascadeCustomDomainDeletion do
  use Ecto.Migration

  def change do
    drop constraint("custom_domains", "custom_domains_site_id_fkey")

    alter table(:custom_domains) do
      modify :site_id, references(:sites, on_delete: :delete_all), null: false
    end
  end
end
