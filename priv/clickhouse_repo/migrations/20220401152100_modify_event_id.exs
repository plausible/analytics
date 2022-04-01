defmodule Plausible.ClickhouseRepo.Migrations.ModifyEventId do
  use Ecto.Migration

  def change do
    alter table(:events) do
      modify(:event_id, :Int128)
    end
  end
end
