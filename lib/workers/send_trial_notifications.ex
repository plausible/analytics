defmodule Plausible.Workers.SendTrialNotifications do
  use Plausible.Repo

  use Oban.Worker,
    queue: :trial_notification_emails,
    max_attempts: 1

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    users =
      Repo.all(
        from u in Plausible.Auth.User,
          left_join: s in Plausible.Billing.Subscription,
          on: s.user_id == u.id,
          where: is_nil(s.id),
          order_by: u.inserted_at
      )

    for user <- users do
      case Timex.diff(user.trial_expiry_date, Timex.today(), :days) do
        7 ->
          if Plausible.Auth.has_active_sites?(user, [:owner]) do
            send_one_week_reminder(user)
          end

        1 ->
          if Plausible.Auth.has_active_sites?(user, [:owner]) do
            send_tomorrow_reminder(user)
          end

        0 ->
          if Plausible.Auth.has_active_sites?(user, [:owner]) do
            send_today_reminder(user)
          end

        -1 ->
          if Plausible.Auth.has_active_sites?(user, [:owner]) do
            send_over_reminder(user)
          end

        _ ->
          nil
      end
    end

    :ok
  end

  defp send_one_week_reminder(user) do
    PlausibleWeb.Email.trial_one_week_reminder(user)
    |> Plausible.Mailer.send_email_safe()
  end

  defp send_tomorrow_reminder(user) do
    usage = Plausible.Billing.usage_breakdown(user)

    PlausibleWeb.Email.trial_upgrade_email(user, "tomorrow", usage)
    |> Plausible.Mailer.send_email_safe()
  end

  defp send_today_reminder(user) do
    usage = Plausible.Billing.usage_breakdown(user)

    PlausibleWeb.Email.trial_upgrade_email(user, "today", usage)
    |> Plausible.Mailer.send_email_safe()
  end

  defp send_over_reminder(user) do
    PlausibleWeb.Email.trial_over_email(user)
    |> Plausible.Mailer.send_email_safe()
  end
end
