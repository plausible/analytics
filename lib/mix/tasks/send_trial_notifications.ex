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
        where: is_nil(s.id)
      )

    two_weeks_left = from(
      u in base_query,
      where: type(u.inserted_at, :date) == fragment("now()::date - '14 days'::interval")
    )

    tomorrow = from(
      u in base_query,
      where: type(u.inserted_at, :date) == fragment("now()::date - '29 days'::interval")
    )

    today = from(
      u in base_query,
      where: type(u.inserted_at, :date) == fragment("now()::date - '30 days'::interval")
    )

    yesterday = from(
      u in base_query,
      where: type(u.inserted_at, :date) == fragment("now()::date - '31 days'::interval")
    )

    for user <- Repo.all(two_weeks_left) do
      if Plausible.Auth.user_completed_setup?(user), do: send_two_week_reminder(args, user)
    end

    for user <- Repo.all(tomorrow) do
      if Plausible.Auth.user_completed_setup?(user), do: send_tomorrow_reminder(args, user)
    end

    for user <- Repo.all(today) do
      if Plausible.Auth.user_completed_setup?(user), do: send_today_reminder(args, user)
    end

    for user <- Repo.all(yesterday) do
      if Plausible.Auth.user_completed_setup?(user), do: send_over_reminder(args, user)
    end
  end

  defp send_two_week_reminder(["--dry-run"], user) do
    Logger.info("DRY RUN: trial notification email to #{user.name}")
  end

  defp send_two_week_reminder(_, user) do
    PlausibleWeb.Email.trial_two_week_reminder(user)
    |> Plausible.Mailer.deliver_now()
  end

  defp send_tomorrow_reminder(["--dry-run"], user) do
    Logger.info("DRY RUN: trial upgrade email to #{user.name}")
  end

  defp send_tomorrow_reminder(_, user) do
    usage = Plausible.Billing.usage(user)

    PlausibleWeb.Email.trial_upgrade_email(user, "tomorrow", usage)
    |> Plausible.Mailer.deliver_now()
  end

  defp send_today_reminder(["--dry-run"], user) do
    Logger.info("DRY RUN: trial upgrade email to #{user.name}")
  end

  defp send_today_reminder(_, user) do
    usage = Plausible.Billing.usage(user)

    PlausibleWeb.Email.trial_upgrade_email(user, "today", usage)
    |> Plausible.Mailer.deliver_now()
  end

  defp send_over_reminder(["--dry-run"], user) do
    Logger.info("DRY RUN: trial over email to #{user.name}")
  end

  defp send_over_reminder(_, user) do
    PlausibleWeb.Email.trial_over_email(user)
    |> Plausible.Mailer.deliver_now()
  end
end
