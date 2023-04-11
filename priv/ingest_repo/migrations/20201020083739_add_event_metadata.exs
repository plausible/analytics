defmodule Plausible.ClickhouseRepo.Migrations.AddEventMetadata do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :meta, :"Nested(key String, value String)"
    end
  end
end
