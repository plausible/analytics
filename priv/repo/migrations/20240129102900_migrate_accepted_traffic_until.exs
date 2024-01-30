defmodule Plausible.Repo.Migrations.MigrateAcceptedTrafficUntil do
  use Ecto.Migration

  def up do
    # all the non-free, active subscriptions
    execute """
    UPDATE users u1
    SET accept_traffic_until = s.next_bill_date + 30
    FROM users u2
    INNER JOIN subscriptions s ON u2.id = s.user_id
    WHERE
    u1.id = u2.id
    AND
    s.user_id = u1.id
    AND
    s.paddle_plan_id != 'free_10k'
    AND
    s.status = 'active'
    AND
    u1.accept_traffic_until <= s.next_bill_date
    """
  end

  def down do
    raise "irreversible"
  end
end
