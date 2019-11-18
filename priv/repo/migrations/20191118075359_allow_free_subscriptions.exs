defmodule Plausible.Repo.Migrations.AllowFreeSubscriptions do
  use Ecto.Migration

  def up do
    execute """
    ALTER table subscriptions
      ALTER paddle_subscription_id DROP NOT NULL,
      ALTER update_url DROP NOT NULL,
      ALTER cancel_url DROP NOT NULL,
      ALTER next_bill_date DROP NOT NULL
    """
  end

  def down do
  end
end
