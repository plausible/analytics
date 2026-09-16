defmodule Plausible.Workers.SendDeletionNotifications do
  @moduledoc """
  Sends the deletion pipeline reminder notices
  (backlog trials, and all churned subscriptions) - steady state
  teams get notified via AcceptTrafficUntil

  Re-checks each team's subscription right before firing, via
  `cancel_for_team` - so that just reactivated team, doesn't get notified.
  """

  use Oban.Worker, queue: :deletion_notification_emails, max_attempts: 1

  alias Plausible.TeamDeletionSchedules
  alias Plausible.Teams
  alias Plausible.Teams.DeletionSchedule

  @spec telemetry_run_event() :: [atom()]
  def telemetry_run_event(), do: [:plausible, :send_deletion_notifications, :run]

  @impl Oban.Worker
  def perform(_job, today \\ Date.utc_today()) do
    # Anchor to `today`
    now = NaiveDateTime.new!(today, ~T[00:00:00])

    send_first_notices(today, now)
    send_reminders(today, now)

    :ok
  end

  defp send_first_notices(today, now) do
    for schedule <- TeamDeletionSchedules.due_for_first_notice(today) do
      send_first_notice(schedule, now)
    end
  end

  defp send_first_notice(schedule, now) do
    team = schedule.team

    if TeamDeletionSchedules.cancel_for_team(team) == :no_schedule do
      # Finalize the schedule (which, for backlog rows, anchors deletion_date
      # to `now`) before composing the email, so the date we tell the
      # customer matches the date we actually persist.
      case TeamDeletionSchedules.mark_first_notice_sent(schedule,
             now: now,
             report_if_invalid?: true
           ) do
        {:ok, schedule} ->
          summary = sites_summary(team)

          for recipient <- team.owners ++ team.billing_members do
            recipient
            |> PlausibleWeb.Email.deletion_full_notice_email(team, schedule, summary)
            |> Plausible.Mailer.send()
          end

          report(schedule, :first_notice, :sent)

        {:error, _} ->
          :ok
      end
    else
      report(schedule, :first_notice, :cancelled)
    end
  end

  defp send_reminders(today, now) do
    for schedule <- TeamDeletionSchedules.due_for_reminder(today) do
      send_reminder(schedule, now)
    end
  end

  defp send_reminder(schedule, now) do
    team = schedule.team

    if TeamDeletionSchedules.cancel_for_team(team) == :no_schedule do
      summary = sites_summary(team)

      for recipient <- team.owners ++ team.billing_members do
        recipient
        |> PlausibleWeb.Email.deletion_reminder_email(team, schedule, summary)
        |> Plausible.Mailer.send()
      end

      TeamDeletionSchedules.mark_reminder_sent(schedule, now: now, report_if_invalid?: true)
      report(schedule, :reminder, :sent)
    else
      report(schedule, :reminder, :cancelled)
    end
  end

  defp report(schedule, stage, outcome) do
    :telemetry.execute(telemetry_run_event(), %{count: 1}, %{
      stage: stage,
      outcome: outcome,
      category: schedule.category
    })
  end

  @spec sites_summary(Teams.Team.t()) :: %{domains: [String.t()], more_count: non_neg_integer()}
  def sites_summary(team) do
    limit = DeletionSchedule.notification_site_list_limit()
    domains = team |> Teams.owned_sites(limit) |> Enum.map(& &1.domain)
    total = Teams.owned_sites_count(team)

    %{domains: domains, more_count: max(total - length(domains), 0)}
  end
end
