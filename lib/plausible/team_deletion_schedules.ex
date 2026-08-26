defmodule Plausible.TeamDeletionSchedules do
  @moduledoc """
  Context for scheduling inactive teams deletion (trial expired or subscription
  churned).
  """

  import Ecto.Query

  require Plausible.Billing.Subscription.Status

  alias Plausible.Billing.Subscription
  alias Plausible.Billing.Subscriptions
  alias Plausible.Repo
  alias Plausible.Site
  alias Plausible.TeamDeletionSchedule
  alias Plausible.Teams
  alias Plausible.Teams.DeletionSchedule

  @doc """
  Finds newly eligible teams (expired trial/churned subscription) and
  schedules each for the deletion pipeline. Reactivation is handled
  via billing (Paddle) handlers.
  """
  @spec sync_eligible(Date.t()) :: non_neg_integer()
  def sync_eligible(today \\ Date.utc_today()) do
    candidates =
      Repo.all(
        from(t in Teams.Team,
          as: :team,
          left_lateral_join: s in subquery(Teams.last_subscription_join_query()),
          on: true,
          left_join: ep in assoc(t, :enterprise_plan),
          where: is_nil(ep.id),
          where: exists(from(s in Site.regular(), where: s.team_id == parent_as(:team).id)),
          where: ^eligible_category?(today),
          where:
            not exists(
              from(sch in TeamDeletionSchedule,
                where: sch.team_id == parent_as(:team).id,
                where: sch.status in ^TeamDeletionSchedule.active_statuses()
              )
            ),
          select: %{
            team_id: t.id,
            has_subscription?: not is_nil(s.id),
            trial_expiry_date: t.trial_expiry_date,
            next_bill_date: s.next_bill_date
          }
        )
      )

    now = NaiveDateTime.utc_now(:second)
    rows = Enum.map(candidates, &build_schedule_row(&1, today, now))

    {count, _} =
      Repo.insert_all(TeamDeletionSchedule, rows,
        on_conflict: :nothing,
        conflict_target: {:unsafe_fragment, terminal_statuses_index_predicate()}
      )

    count
  end

  @doc """
  Cancels any pending deletion schedule for a team
  """
  @spec cancel_for_team(Teams.Team.t()) :: non_neg_integer()
  def cancel_for_team(team) do
    team = Teams.with_subscription(team)

    if Subscriptions.active?(team.subscription) do
      {:ok, count} =
        Repo.transact(fn ->
          case active_schedule_for(team.id) do
            nil ->
              {:ok, 0}

            schedule ->
              case cancel(schedule) do
                {:ok, _} -> {:ok, 1}
                {:error, _} -> {:ok, 0}
              end
          end
        end)

      count
    else
      0
    end
  end

  @type transition_result ::
          {:ok, TeamDeletionSchedule.t()} | {:error, {:invalid_transition, atom(), atom()}}

  @transitions %{
    scheduled: [:first_notice_sent, :cancelled, :snoozed],
    first_notice_sent: [:reminder_sent, :cancelled, :snoozed],
    reminder_sent: [:completed, :cancelled, :snoozed],
    snoozed: [:cancelled, :scheduled],
    completed: [],
    cancelled: []
  }

  @spec transitions() :: %{atom() => [atom()]}
  def transitions, do: @transitions

  @spec mark_first_notice_sent(TeamDeletionSchedule.t(), NaiveDateTime.t()) :: transition_result
  def mark_first_notice_sent(schedule, now \\ NaiveDateTime.utc_now(:second))

  def mark_first_notice_sent(%TeamDeletionSchedule{is_backlog: true} = schedule, now) do
    transition(schedule, :first_notice_sent, %{
      first_notice_sent_at: now,
      deletion_date: DeletionSchedule.backlog_deletion_date(now)
    })
  end

  def mark_first_notice_sent(%TeamDeletionSchedule{is_backlog: false} = schedule, now) do
    transition(schedule, :first_notice_sent, %{first_notice_sent_at: now})
  end

  @spec mark_reminder_sent(TeamDeletionSchedule.t(), NaiveDateTime.t()) :: transition_result
  def mark_reminder_sent(schedule, now \\ NaiveDateTime.utc_now(:second)) do
    transition(schedule, :reminder_sent, %{reminder_sent_at: now})
  end

  @spec mark_completed(TeamDeletionSchedule.t()) :: transition_result
  def mark_completed(schedule) do
    transition(schedule, :completed)
  end

  @spec cancel(TeamDeletionSchedule.t()) :: transition_result
  def cancel(schedule) do
    transition(schedule, :cancelled)
  end

  @spec snooze(TeamDeletionSchedule.t(), Date.t(), String.t() | nil) :: transition_result
  def snooze(schedule, until_date, note \\ nil) do
    transition(schedule, :snoozed, %{snoozed_until: until_date, snooze_note: note})
  end

  @doc """
  Unsnoozes a schedule once its snooze has lapsed without the team
  resubscribing. Restarts the notice cycle from scratch
  """
  @spec unsnooze(TeamDeletionSchedule.t(), Date.t()) :: transition_result
  def unsnooze(schedule, today \\ Date.utc_today()) do
    transition(schedule, :scheduled, %{
      is_backlog: true,
      first_notice_due_date: today,
      first_notice_sent_at: nil,
      reminder_sent_at: nil,
      snoozed_until: nil,
      snooze_note: nil
    })
  end

  @valid_transitions for {from, tos} <- @transitions, to <- tos, do: {from, to}

  defp transition(schedule, to, extra_changes \\ %{})

  defp transition(%TeamDeletionSchedule{status: from} = schedule, to, extra_changes)
       when {from, to} in @valid_transitions do
    updated =
      schedule
      |> Ecto.Changeset.change(Map.put(extra_changes, :status, to))
      |> Repo.update!()

    {:ok, updated}
  end

  defp transition(%TeamDeletionSchedule{status: from}, to, _extra_changes) do
    {:error, {:invalid_transition, from, to}}
  end

  defp active_schedule_for(team_id) do
    TeamDeletionSchedule
    |> where([sch], sch.team_id == ^team_id)
    |> where([sch], sch.status in ^TeamDeletionSchedule.active_statuses())
    |> lock("FOR UPDATE")
    |> Repo.one()
  end

  defp eligible_category?(today) do
    dynamic(^expired_trial?(today) or ^churned_subscription?(today))
  end

  defp expired_trial?(today) do
    dynamic(
      [t, s],
      is_nil(s.id) and not is_nil(t.trial_expiry_date) and t.trial_expiry_date < ^today
    )
  end

  defp churned_subscription?(today) do
    dynamic(
      [_t, s],
      not is_nil(s.id) and
        s.status in [^Subscription.Status.deleted(), ^Subscription.Status.paused()] and
        s.paddle_plan_id != "free_10k" and s.next_bill_date < ^today
    )
  end

  defp terminal_statuses_index_predicate do
    values = Enum.map_join(TeamDeletionSchedule.terminal_statuses(), ", ", &"'#{&1}'")
    "(team_id) WHERE status NOT IN (#{values})"
  end

  defp build_schedule_row(candidate, today, now) do
    {category, expiry_date} =
      if candidate.has_subscription? do
        {:churned_subscription, candidate.next_bill_date}
      else
        {:expired_trial, candidate.trial_expiry_date}
      end

    deletion_date = DeletionSchedule.deletion_date(category, expiry_date)
    steady_state_first_notice_due_date = DeletionSchedule.first_notice_due_date(deletion_date)
    is_backlog? = Date.before?(steady_state_first_notice_due_date, today)

    %{
      team_id: candidate.team_id,
      category: category,
      expiry_date: expiry_date,
      deletion_date: deletion_date,
      # Backlog rows will be spread-out eventually.
      # `today` is temporary for now.
      first_notice_due_date: if(is_backlog?, do: today, else: steady_state_first_notice_due_date),
      is_backlog: is_backlog?,
      status: :scheduled,
      inserted_at: now,
      updated_at: now
    }
  end
end
