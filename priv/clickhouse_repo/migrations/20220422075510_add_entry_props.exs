defmodule Plausible.ClickhouseRepo.Migrations.AddEntryProps do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add(:entry_meta, {:nested, {{:key, :string}, {:value, :string}}})
    end
  end
end
