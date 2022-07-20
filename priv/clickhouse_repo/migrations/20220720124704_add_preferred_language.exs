defmodule Plausible.ClickhouseRepo.Migrations.AddPreferredLanguage do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add(:preferred_language, :"LowCardinality(String)")
    end

    alter table(:sessions) do
      add(:preferred_language, :"LowCardinality(String)")
    end
  end
end
