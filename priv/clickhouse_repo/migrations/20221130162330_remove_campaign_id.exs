defmodule Plausible.ClickhouseRepo.Migrations.RemoveCampaignId do
  use Ecto.Migration

  def change do
    alter table(:events) do
      remove :campaign_id
    end

    alter table(:sessions) do
      remove :campaign_id
    end
  end
end
