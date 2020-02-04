defmodule Mix.Tasks.SendTrialNotifications do
  use Mix.Task
  use Plausible.Repo
  require Logger

  @doc """
  This is scheduled to run every day.
  """

  def run(args) do
    Application.ensure_all_started(:plausible)
    execute(args)
  end

  def execute(args \\ []) do
    base_query =
      from(u in Plausible.Auth.User,
        left_join: s in Plausible.Billing.Subscription, on: s.user_id == u.id,
        where: is_nil(s.id),
        order_by: u.inserted_at
      )

    users = Repo.all(base_query)

    for user <- users do
      case Timex.diff(Plausible.Billing.trial_end_date(user), Timex.today(), :days) do
       14 ->
          if Plausible.Auth.user_completed_setup?(user) do
            send_two_week_reminder(args, user)
          end
       1 ->
          if Plausible.Auth.user_completed_setup?(user) do
            send_tomorrow_reminder(args, user)
          end
       0 ->
          if Plausible.Auth.user_completed_setup?(user) do
            send_today_reminder(args, user)
          end
       -1 ->
          if Plausible.Auth.user_completed_setup?(user) do
            send_over_reminder(args, user)
          end
        _ ->
          nil
      end
    end
  end

  defp send_two_week_reminder(["--dry-run"], user) do
    Logger.info("DRY RUN: 2-week trial notification email to #{user.name} [inserted=#{user.inserted_at}]")
  end

  defp send_two_week_reminder(_, user) do
    PlausibleWeb.Email.trial_two_week_reminder(user)
    |> Plausible.Mailer.deliver_now()
  end

  defp send_tomorrow_reminder(["--dry-run"], user) do
    Logger.info("DRY RUN: tomorrow trial upgrade email to #{user.name} [inserted=#{user.inserted_at}]")
  end

  defp send_tomorrow_reminder(_, user) do
    usage = Plausible.Billing.usage(user)

    PlausibleWeb.Email.trial_upgrade_email(user, "tomorrow", usage)
    |> Plausible.Mailer.deliver_now()
  end

  defp send_today_reminder(["--dry-run"], user) do
    Logger.info("DRY RUN: today trial upgrade email to #{user.name} [inserted=#{user.inserted_at}]")
  end

  defp send_today_reminder(_, user) do
    usage = Plausible.Billing.usage(user)

    PlausibleWeb.Email.trial_upgrade_email(user, "today", usage)
    |> Plausible.Mailer.deliver_now()
  end

  defp send_over_reminder(["--dry-run"], user) do
    Logger.info("DRY RUN: over trial notification email to #{user.name} [inserted=#{user.inserted_at}]")
  end

  defp send_over_reminder(_, user) do
    PlausibleWeb.Email.trial_over_email(user)
    |> Plausible.Mailer.deliver_now()
  end
end
