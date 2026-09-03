defmodule Plausible.Workers.UnsnoozeTeamDeletions do
  @moduledoc """
  Restarts the notice cycle for schedules whose snooze has lapsed: still
  `:snoozed`, past their `snoozed_until` date.
  """

  use Oban.Worker, queue: :unsnooze_team_deletions, max_attempts: 1

  alias Plausible.TeamDeletionSchedules

  @impl Oban.Worker
  def perform(_job, today \\ Date.utc_today()) do
    for schedule <- TeamDeletionSchedules.due_for_unsnooze(today) do
      TeamDeletionSchedules.unsnooze(schedule, today: today, report_if_invalid?: true)
    end

    :ok
  end
end
