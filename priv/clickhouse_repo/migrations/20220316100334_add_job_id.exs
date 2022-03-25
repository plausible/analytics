defmodule Plausible.ClickhouseRepo.Migrations.AddJobId do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add(:job_id, :UInt64)
    end
  end
end
