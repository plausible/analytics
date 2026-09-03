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
      team = schedule.team

      if TeamDeletionSchedules.cancel_for_team(team) == 0 do
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

          {:error, _} ->
            :ok
        end
      end
    end
  end

  defp send_reminders(today, now) do
    for schedule <- TeamDeletionSchedules.due_for_reminder(today) do
      team = schedule.team

      if TeamDeletionSchedules.cancel_for_team(team) == 0 do
        summary = sites_summary(team)

        for recipient <- team.owners ++ team.billing_members do
          recipient
          |> PlausibleWeb.Email.deletion_reminder_email(team, schedule, summary)
          |> Plausible.Mailer.send()
        end

        TeamDeletionSchedules.mark_reminder_sent(schedule, now: now, report_if_invalid?: true)
      end
    end
  end

  @spec sites_summary(Teams.Team.t()) :: %{domains: [String.t()], more_count: non_neg_integer()}
  def sites_summary(team) do
    limit = DeletionSchedule.notification_site_list_limit()
    domains = team |> Teams.owned_sites(limit) |> Enum.map(& &1.domain)
    total = Teams.owned_sites_count(team)

    %{domains: domains, more_count: max(total - length(domains), 0)}
  end
end
