defmodule Plausible.Repo.Migrations.CreateSegmentsAndSegmentUsers do
  use Ecto.Migration

  def change do
    create table(:segments) do
      add :name, :string, null: false
      add :personal, :boolean, default: true, null: false
      add :segment_data, :map, null: false
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :owner_id, references(:users, on_delete: :nothing), null: false

      timestamps()
    end

    create index(:segments, [:segment_data], using: :gin)
    create index(:segments, [:site_id])
  end
end
