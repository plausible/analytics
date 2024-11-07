defmodule Plausible.Repo.Migrations.CreateSegments do
  use Ecto.Migration

  def change do
    create table(:segments) do
      add :name, :string, null: false
      add :personal, :boolean, default: true, null: false
      add :segment_data, :map, null: false
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      # owner_id is null (aka segment is dangling) when the original owner is deassociated from the site
      # the segment is dangling until another user edits it: the editor becomes the new owner
      add :owner_id, references(:users, on_delete: :nothing), null: true

      timestamps()
    end

    create index(:segments, [:segment_data], using: :gin)
    create index(:segments, [:site_id])
  end
end
