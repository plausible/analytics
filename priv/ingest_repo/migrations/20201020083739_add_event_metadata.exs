defmodule Plausible.ClickhouseRepo.Migrations.AddEventMetadata do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :meta, {:nested, {{:key, :string}, {:value, :string}}}
    end
  end
end
