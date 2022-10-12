defmodule Plausible.ClickhouseRepo.Migrations.RemoveEntryProps do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      remove(:"entry.meta")
    end
  end
end
