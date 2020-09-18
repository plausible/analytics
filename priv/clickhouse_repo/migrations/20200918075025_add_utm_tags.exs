defmodule Plausible.ClickhouseRepo.Migrations.AddUtmTags do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :utm_medium, :string
      add :utm_source, :string
      add :utm_campaign, :string
    end

    alter table(:sessions) do
      add :utm_medium, :string
      add :utm_source, :string
      add :utm_campaign, :string
    end
  end
end
