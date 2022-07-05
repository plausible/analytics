defmodule Plausible.Repo.Migrations.AddTimeformatColumnToSites do
  use Ecto.Migration

  def up do
    execute "CREATE TYPE timeformat AS ENUM ('am/pm', '24h')"

    alter table(:sites) do
      add :timeformat, :timeformat, null: false, default: "am/pm"
    end
  end

  def down do
    execute "DROP TYPE timeformat"

    alter table(:sites) do
      remove :timeformat
    end
  end
end
