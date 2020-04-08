defmodule Plausible.Repo.Migrations.CascadeSetupEmailsDeletion do
  use Ecto.Migration

  def change do
    drop constraint("setup_help_emails", "setup_help_emails_site_id_fkey")
    drop constraint("setup_success_emails", "setup_success_emails_site_id_fkey")

    alter table(:setup_help_emails) do
      modify :site_id, references(:sites, on_delete: :delete_all), null: false
    end

    alter table(:setup_success_emails) do
      modify :site_id, references(:sites, on_delete: :delete_all), null: false
    end
  end
end
