defmodule Plausible.ClickhouseRepo.Migrations.RemoveProductId do
  use Ecto.Migration

  def change do
    alter table(:events) do
      remove :product_id
    end

    alter table(:sessions) do
      remove :product_id
    end
  end
end
