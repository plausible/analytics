defmodule Plausible.ClickhouseRepo.Migrations.AddCompanyId do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add(:company_id, :UInt64)
    end

    alter table(:sessions) do
      add(:company_id, :UInt64)
    end
  end
end
