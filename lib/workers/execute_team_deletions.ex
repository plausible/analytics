defmodule Plausible.Workers.ExecuteTeamDeletions do
  @moduledoc """
  Executes deletions for schedules whose reminder has been sent and whose
  deletion_date has arrived: deletes the team's sites (and queues their
  stats for removal) - the team itself and its settings/subscription
  history are left intact. Marks the schedule completed.

  Re-checks each team's subscription right before acting, via
  `cancel_for_team` - so a just-reactivated team doesn't have its sites
  deleted.
  """

  use Oban.Worker, queue: :execute_team_deletions, max_attempts: 1

  alias Plausible.Repo
  alias Plausible.TeamDeletionSchedules
  alias Plausible.Teams

  @spec telemetry_run_event() :: [atom()]
  def telemetry_run_event(), do: [:plausible, :execute_team_deletions, :run]

  @spec telemetry_sites_deleted_event() :: [atom()]
  def telemetry_sites_deleted_event(), do: [:plausible, :execute_team_deletions, :sites_deleted]

  @impl Oban.Worker
  def perform(_job, today \\ Date.utc_today()) do
    for schedule <- TeamDeletionSchedules.due_for_deletion(today) do
      team = schedule.team

      if TeamDeletionSchedules.cancel_for_team(team) == :no_schedule do
        execute(schedule, team)
      else
        report(schedule, :cancelled)
      end
    end

    :ok
  end

  defp execute(schedule, team) do
    Repo.transaction(fn ->
      sites = Teams.owned_sites(team)

      for site <- sites do
        Plausible.Site.Removal.run(site, reason: schedule.category)
      end

      TeamDeletionSchedules.mark_completed(schedule, report_if_invalid?: true)

      report(schedule, :executed)

      :telemetry.execute(telemetry_sites_deleted_event(), %{count: length(sites)}, %{
        category: schedule.category
      })
    end)
  end

  defp report(schedule, outcome) do
    :telemetry.execute(telemetry_run_event(), %{count: 1}, %{
      outcome: outcome,
      category: schedule.category
    })
  end
end
