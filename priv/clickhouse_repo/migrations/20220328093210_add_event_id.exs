defmodule Plausible.ClickhouseRepo.Migrations.AddEventId do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add(:event_id, :UInt64)
    end
  end
end
