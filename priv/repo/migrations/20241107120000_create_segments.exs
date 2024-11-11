defmodule Plausible.Repo.Migrations.CreateSegments do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE segment_type AS ENUM ('personal', 'site')",
      "DROP TYPE segment_type"
    )

    create table(:segments) do
      add :name, :string, null: false
      add :type, :segment_type, null: false, default: "personal"
      add :segment_data, :map, null: false
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :owner_id, references(:users, on_delete: :nothing), null: true

      timestamps()
    end

    create index(:segments, [:site_id])
  end
end
