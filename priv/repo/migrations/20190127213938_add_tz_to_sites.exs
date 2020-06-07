defmodule Plausible.Repo.Migrations.AddTzToSites do
  use Ecto.Migration
  use Plausible.Repo

  def change do
    alter table(:sites) do
      add :timezone, :string
    end

    flush()

    Repo.update_all(Plausible.Site, set: [timezone: "UTC"])

    alter table(:sites) do
      modify :timezone, :string, null: false
    end
  end
end
