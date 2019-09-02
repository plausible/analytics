defmodule Plausible.Repo.Migrations.AddCountryCodeToPageviews do
  use Ecto.Migration

  def change do
    alter table(:pageviews) do
      add :country_code, :string, size: 2
    end
  end
end
