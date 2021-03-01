defmodule Plausible.Repo.Migrations.AddLastPaymentDetails do
  use Ecto.Migration

  def change do
    alter table(:subscriptions) do
      add :last_bill_date, :date
    end
  end
end
