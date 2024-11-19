defmodule Plausible.IngestRepo.Migrations.AddScrollDepthToEvents do
  use Ecto.Migration

  def change do
    alter table(:events_v2) do
      add :scroll_depth, :UInt8
    end
  end
end
