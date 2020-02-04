defmodule Plausible.Repo.Migrations.RenameSiteIdToDomain do
  use Ecto.Migration

  def change do
    rename table(:events), :site_id, to: :domain
    rename table(:sessions), :site_id, to: :domain
  end
end
