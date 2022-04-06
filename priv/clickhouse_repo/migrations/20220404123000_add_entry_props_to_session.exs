defmodule Plausible.ClickhouseRepo.Migrations.AddEntryPropsToSession do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :"entry.meta", {:nested, {{:key, :string}, {:value, :string}}}
    end
  end
end
