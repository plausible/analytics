defmodule Plausible.Repo.Migrations.AddPropertyToGoogleAuth do
  use Ecto.Migration
  use Plausible.Repo

  def change do
    alter table(:google_auth) do
      add :property, :text
    end
  end
end
