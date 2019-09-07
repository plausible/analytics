defmodule Plausible.Repo.Migrations.AddUniqueIndexToEmailSettings do
  use Ecto.Migration

  def change do
    create unique_index(:email_settings, :site_id)
  end
end
