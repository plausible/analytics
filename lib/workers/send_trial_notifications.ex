defmodule Plausible.Workers.SendTrialNotifications do
  use Plausible.Repo

  use Oban.Worker,
    queue: :trial_notification_emails,
    max_attempts: 1

  alias Plausible.Teams

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    teams =
      Repo.all(
        from t in Teams.Team,
          inner_join: o in assoc(t, :owners),
          left_join: s in assoc(t, :subscription),
          where: not is_nil(t.trial_expiry_date),
          where: is_nil(s.id),
          order_by: t.inserted_at,
          preload: [owners: o]
      )

    for team <- teams do
      case Date.diff(team.trial_expiry_date, Date.utc_today()) do
        7 ->
          if Teams.has_active_sites?(team) do
            send_one_week_reminder(team.owners)
          end

        1 ->
          if Teams.has_active_sites?(team) do
            send_tomorrow_reminder(team.owners, team)
          end

        0 ->
          if Teams.has_active_sites?(team) do
            send_today_reminder(team.owners, team)
          end

        -1 ->
          if Teams.has_active_sites?(team) do
            send_over_reminder(team.owners)
          end

        _ ->
          nil
      end
    end

    :ok
  end

  defp send_one_week_reminder(users) do
    for user <- users do
      PlausibleWeb.Email.trial_one_week_reminder(user)
      |> Plausible.Mailer.send()
    end
  end

  defp send_tomorrow_reminder(users, team) do
    usage = Plausible.Teams.Billing.usage_cycle(team, :last_30_days)
    suggested_plan = Plausible.Billing.Plans.suggest(team, usage.total)

    for user <- users do
      PlausibleWeb.Email.trial_upgrade_email(user, "tomorrow", usage, suggested_plan)
      |> Plausible.Mailer.send()
    end
  end

  defp send_today_reminder(users, team) do
    usage = Plausible.Teams.Billing.usage_cycle(team, :last_30_days)
    suggested_plan = Plausible.Billing.Plans.suggest(team, usage.total)

    for user <- users do
      PlausibleWeb.Email.trial_upgrade_email(user, "today", usage, suggested_plan)
      |> Plausible.Mailer.send()
    end
  end

  defp send_over_reminder(users) do
    for user <- users do
      PlausibleWeb.Email.trial_over_email(user)
      |> Plausible.Mailer.send()
    end
  end
end
