defmodule Plausible.ClickhouseRepo.Migrations.AddEntryPropsToSession do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :"entry.meta", :"Nested(key String, value String)"
    end
  end
end
