defmodule PlausibleWeb.Api.CustomerSupport.DeletionController do
  @moduledoc """
  Snoozing and unsnoozing a team's scheduled deletion, and deleting an old
  site that blocks a new signup.
  """
  use PlausibleWeb, :controller

  alias Plausible.Billing.Subscriptions
  alias Plausible.{TeamDeletionSchedule, TeamDeletionSchedules}
  alias PlausibleWeb.Api.CustomerSupport.Helpers, as: H

  @site_deletions_per_day 5

  def snooze(conn, params) do
    H.run_team_action(conn, params, "deletion_snoozed", fn team ->
      with {:ok, schedule} <- active_schedule(team),
           changeset =
             TeamDeletionSchedule.crm_changeset(schedule, %{
               "snoozed_until" => params["snoozed_until"],
               "snooze_note" => params["snooze_note"]
             }),
           :ok <- if(changeset.valid?, do: :ok, else: {:error, changeset}),
           until = Ecto.Changeset.get_change(changeset, :snoozed_until),
           note = Ecto.Changeset.get_change(changeset, :snooze_note),
           {:ok, schedule} <-
             transition(TeamDeletionSchedules.snooze(schedule, until, note: note)) do
        {:ok, team, %{status: schedule.status, snoozed_until: until, snooze_note: note}}
      end
    end)
  end

  def unsnooze(conn, params) do
    H.run_team_action(conn, params, "deletion_unsnoozed", fn team ->
      with {:ok, schedule} <- active_schedule(team),
           :ok <- H.guard(schedule.status == :snoozed, "The deletion isn't snoozed"),
           {:ok, schedule} <- transition(TeamDeletionSchedules.unsnooze(schedule)) do
        {:ok, team, %{status: schedule.status}}
      end
    end)
  end

  @doc """
  Deletes a site only when its team is no longer paying or trialling. The
  request must name the domain as well as the id.

  A cancelled subscription with paid time left blocks it, on purpose: this
  is support clean-up (usually an old site blocking someone's new signup),
  not something the paying customer asked for, so their paid time is left
  alone.
  """
  def delete_site(conn, params) do
    H.run_site_action(
      conn,
      params,
      "site_deleted",
      fn site ->
        team = Plausible.Teams.with_subscription(site.team)

        with :ok <- H.guard(params["domain"] == site.domain, "The domain doesn't match the site"),
             :ok <-
               H.guard(not Plausible.Teams.on_trial?(team), "The team's trial is still running"),
             :ok <-
               H.guard(
                 not paid_period_running?(team.subscription),
                 "The team still has a paid period"
               ) do
          {:ok, _} = Plausible.Site.Removal.run(site)
          {:ok, site, %{deleted: true, domain: site.domain}}
        end
      end,
      limit: @site_deletions_per_day
    )
  end

  defp active_schedule(team) do
    case TeamDeletionSchedules.active_schedule_for_team(team) do
      nil -> {:error, :guard, "The team has no deletion scheduled"}
      schedule -> {:ok, schedule}
    end
  end

  defp transition({:ok, schedule}), do: {:ok, schedule}

  defp transition({:error, {:invalid_transition, _, _}}) do
    {:error, :guard, "The deletion schedule isn't in a state that allows this"}
  end

  # Active, past due or paused, or cancelled with time left on the last payment.
  defp paid_period_running?(nil), do: false

  defp paid_period_running?(subscription) do
    Subscriptions.active?(subscription) or Subscriptions.resumable?(subscription)
  end
end
