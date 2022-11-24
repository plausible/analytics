defmodule Plausible.ClickhouseRepo.Migrations.AddCampaignIdAndProductId do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add(:campaign_id, :UInt64)
      add(:product_id, :UInt64)
    end

    alter table(:sessions) do
      add(:campaign_id, :UInt64)
      add(:product_id, :UInt64)
    end
  end
end
