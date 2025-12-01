defmodule Plausible.Repo.Migrations.AddLimitedToSegmentToSharedLinks do
  use Ecto.Migration

  def change do
    alter table(:shared_links) do
      add :limited_to_segment_id, :integer, null: true
    end
  end
end
