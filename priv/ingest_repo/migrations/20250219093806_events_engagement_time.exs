defmodule Plausible.IngestRepo.Migrations.EventsEngagementTime do
  use Ecto.Migration

  def change do
    alter table(:events_v2) do
      add :engagement_time, :UInt32
    end
  end
end
