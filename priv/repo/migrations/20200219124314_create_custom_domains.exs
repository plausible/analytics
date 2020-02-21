defmodule Plausible.Repo.Migrations.CreateCustomDomains do
  use Ecto.Migration

  def change do
    create table(:custom_domains) do
      add :domain, :text, null: false
      add :site_id, references(:sites), null: false
      add :has_ssl_certificate, :boolean, null: false, default: false

      timestamps()
    end

    create unique_index(:custom_domains, :site_id)
  end
end
