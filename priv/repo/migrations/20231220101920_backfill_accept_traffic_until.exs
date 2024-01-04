defmodule Plausible.Repo.Migrations.BackfillAcceptTrafficUntil do
  use Ecto.Migration

  def change do
    # trials that are about to expire get extra 14 days
    # regardless of the effective end date, this still leaves a room for both notifications
    execute """
    UPDATE users
    SET accept_traffic_until = trial_expiry_date + 14
    WHERE
      trial_expiry_date IS NOT NULL
    AND
      trial_expiry_date >= CURRENT_DATE
    """

    # free plans
    execute """
    UPDATE users AS u
    SET accept_traffic_until = '2135-01-01'
    WHERE
      EXISTS (
        SELECT 1
        FROM subscriptions s
        WHERE
          user_id = u.id
        AND
          paddle_plan_id = 'free_10k'
      )
    """

    # abandoned accounts (trial ended and no valid subscriptions) still get a random
    # phase-out period so that both notifications can be delivered
    execute """
    UPDATE users
    SET accept_traffic_until = CURRENT_DATE + TRUNC(RANDOM() * (20 - 8 + 1) + 8)::int
    WHERE
      NOT EXISTS (
        SELECT 1
        FROM subscriptions
        WHERE
          subscriptions.user_id = users.id
      )
    AND
      trial_expiry_date IS NOT NULL
    AND
      trial_expiry_date < CURRENT_DATE
    """

    # all the non-free subscriptions
    execute """
    UPDATE users u1
    SET accept_traffic_until = s.next_bill_date + 30
    FROM users u2
    INNER JOIN LATERAL (
      SELECT * FROM subscriptions sub WHERE u2.id = sub.user_id ORDER BY sub.inserted_at DESC LIMIT 1
    ) s ON (true)
    WHERE
      u1.id = u2.id
    AND
      s.user_id = u1.id
    AND
      s.paddle_plan_id != 'free_10k'
    """

    # subscription for which current period needs payment)
    execute """
    UPDATE users u1
    SET accept_traffic_until = CURRENT_DATE + TRUNC(RANDOM() * (20 - 8 + 1) + 8)::int
    FROM users u2
    INNER JOIN LATERAL (
      SELECT * FROM subscriptions sub WHERE u2.id = sub.user_id ORDER BY sub.inserted_at DESC LIMIT 1
    ) s ON (true)
    WHERE
      s.user_id = u1.id
    AND
      u1.id = u2.id
    AND
      s.next_bill_date < CURRENT_DATE
    """
  end
end
