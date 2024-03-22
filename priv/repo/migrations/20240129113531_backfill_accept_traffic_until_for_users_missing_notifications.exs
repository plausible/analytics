defmodule Plausible.Repo.Migrations.BackfillAcceptTrafficUntilForUsersMissingNotifications do
  use Ecto.Migration

  def up do
    execute """
    UPDATE users u
    SET accept_traffic_until = '2024-01-31'
    WHERE
    u.accept_traffic_until IN ('2024-01-29', '2024-01-30')
    AND EXISTS (
      select 1 from sent_accept_traffic_until_notifications
      WHERE user_id = u.id
    )
    AND NOT EXISTS (
      select 1 from subscriptions
      WHERE status = 'active'
      AND
      user_id = u.id
    );
    """

    execute """
    UPDATE users u
    SET accept_traffic_until = '2024-02-07'
    WHERE
    u.accept_traffic_until IN ('2024-02-04', '2024-02-05')
    AND NOT EXISTS (
      select 1 from sent_accept_traffic_until_notifications
      WHERE user_id = u.id
    )
    AND NOT EXISTS (
      select 1 from subscriptions 
      WHERE status = 'active'
      AND
      user_id = u.id
    );
    """
  end

  def down do
    raise "irreversible"
  end
end
