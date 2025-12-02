defmodule Plausible.Repo.Migrations.AddLimitedToSegmentToSharedLinks do
  use Ecto.Migration

  def change do
    alter table(:shared_links) do
      add :segment_id, references(:segments, on_delete: :delete_all)
    end
    create index(:shared_links, [:segment_id])
  end
end
