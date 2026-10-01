defmodule Plausible.Repo.Migrations.AddPaidByTransferToSubscriptions do
  use Ecto.Migration

  def change do
    alter table(:subscriptions) do
      add :paid_by_transfer, :boolean, null: false, default: false
    end
  end
end
