defmodule Plausible.Workers.UnsnoozeTeamDeletions do
  @moduledoc """
  Restarts the notice cycle for schedules whose snooze has lapsed: still
  `:snoozed`, past their `snoozed_until` date.
  """

  use Oban.Worker, queue: :unsnooze_team_deletions, max_attempts: 1

  alias Plausible.TeamDeletionSchedules

  @spec telemetry_run_event() :: [atom()]
  def telemetry_run_event(), do: [:plausible, :unsnooze_team_deletions, :run]

  @impl Oban.Worker
  def perform(_job, today \\ Date.utc_today()) do
    due = TeamDeletionSchedules.due_for_unsnooze(today)

    for schedule <- due do
      TeamDeletionSchedules.unsnooze(schedule, today: today, report_if_invalid?: true)
    end

    :telemetry.execute(telemetry_run_event(), %{count: length(due)})

    :ok
  end
end
