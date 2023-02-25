defmodule Plausible.ClickhouseRepo.Migrations.AddBrowserVersionAndOsVersion do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :browser_version, :"LowCardinality(String)"
      add :operating_system_version, :"LowCardinality(String)"
    end

    alter table(:sessions) do
      add :browser_version, :"LowCardinality(String)"
      add :operating_system_version, :"LowCardinality(String)"
    end
  end
end
