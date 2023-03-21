defmodule Plausible.ClickhouseRepo.Migrations.AddEntryProps do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add(:entry_meta, :"Nested(key String, value String)")
    end
  end
end
