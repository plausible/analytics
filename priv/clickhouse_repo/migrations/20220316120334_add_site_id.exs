defmodule Plausible.ClickhouseRepo.Migrations.AddSiteId do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add(:site_id, :UInt64)
    end

    alter table(:sessions) do
      add(:site_id, :UInt64)
    end
  end
end
