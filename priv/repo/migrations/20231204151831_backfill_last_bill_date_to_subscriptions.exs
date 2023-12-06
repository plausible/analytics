defmodule Plausible.Repo.Migrations.BackfillLastBillDateToSubscriptions do
  use Ecto.Migration

  def change do
    execute """
    UPDATE subscriptions
    SET last_bill_date = inserted_at::date
    WHERE last_bill_date IS NULL AND paddle_plan_id != 'free_10k';
    """
  end
end
