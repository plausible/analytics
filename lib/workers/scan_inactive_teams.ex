defmodule Plausible.Workers.ScanInactiveTeams do
  @moduledoc """
  Finds teams whose trial or subscription has expired and schedules them
  for the stats deletion pipeline. Reactivation is handled
  separately and immediately, via `Plausible.TeamDeletionSchedules.cancel_for_team/1`
  called from `Plausible.Billing`'s webhook handlers.
  """

  use Oban.Worker, queue: :scan_inactive_teams

  alias Plausible.TeamDeletionSchedules

  @spec telemetry_run_event() :: [atom()]
  def telemetry_run_event(), do: [:plausible, :scan_inactive_teams, :run]

  @impl Oban.Worker
  def perform(_job) do
    created = TeamDeletionSchedules.sync_eligible()

    :telemetry.execute(telemetry_run_event(), %{created: created})

    :ok
  end
end
