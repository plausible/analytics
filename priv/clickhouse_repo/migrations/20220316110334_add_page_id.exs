defmodule Plausible.ClickhouseRepo.Migrations.AddPageId do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add(:page_id, :UInt64)
    end
  end
end
