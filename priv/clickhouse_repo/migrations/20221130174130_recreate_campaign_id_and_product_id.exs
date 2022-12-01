defmodule Plausible.ClickhouseRepo.Migrations.RecreateCampaignIdAndProductId do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add(:campaign_id, :string)
      add(:product_id, :string)
    end

    alter table(:sessions) do
      add(:campaign_id, :string)
      add(:product_id, :string)
    end
  end
end
