defmodule Plausible.ClickhouseRepo.Migrations.AddTransferredFrom do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add(:transferred_from, :string)
    end

    alter table(:sessions) do
      add(:transferred_from, :string)
    end
  end
end
