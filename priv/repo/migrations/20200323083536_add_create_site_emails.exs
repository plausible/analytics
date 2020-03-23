defmodule Plausible.Repo.Migrations.AddCreateSiteEmails do
  use Ecto.Migration

  def change do
    create table(:create_site_emails) do
      add :user_id, references(:users), null: false, on_delete: :delete_all
      add :timestamp, :naive_datetime
    end
  end
end
