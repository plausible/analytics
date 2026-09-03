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
      cancel_active_schedule(team.id)
    else
      0
    end
  end

  @doc """
  Schedules due for their first notice - still scheduled and
  past their first_notice_due_date.
  """
  @spec due_for_first_notice(Date.t()) :: [TeamDeletionSchedule.t()]
  def due_for_first_notice(today \\ Date.utc_today()) do
    Repo.all(
      from(sch in TeamDeletionSchedule,
        inner_join: t in assoc(sch, :team),
        where: sch.status == :scheduled,
        where: sch.first_notice_due_date <= ^today,
        preload: [team: {t, [:owners, :billing_members]}]
      )
    )
  end

  @doc """
  Schedules due for the reminder: first notice already sent.
  Applies to backlog rows too.
  """
  @spec due_for_reminder(Date.t()) :: [TeamDeletionSchedule.t()]
  def due_for_reminder(today \\ Date.utc_today()) do
    reminder_threshold = Date.add(today, DeletionSchedule.reminder_before_deletion_days())

    Repo.all(
      from(sch in TeamDeletionSchedule,
        inner_join: t in assoc(sch, :team),
        where: sch.status == :first_notice_sent,
        where: sch.deletion_date <= ^reminder_threshold,
        preload: [team: {t, [:owners, :billing_members]}]
      )
    )
  end

  @doc """
  Schedules ready for deletion: reminder already sent, past their
  deletion_date.
  """
  @spec due_for_deletion(Date.t()) :: [TeamDeletionSchedule.t()]
  def due_for_deletion(today \\ Date.utc_today()) do
    Repo.all(
      from(sch in TeamDeletionSchedule,
        inner_join: t in assoc(sch, :team),
        where: sch.status == :reminder_sent,
        where: sch.deletion_date <= ^today,
        preload: [:team]
      )
    )
  end

  @doc """
  Pending, non-backlog expired trial schedules for the
  given team ids, keyed by `team_id`
  """
  @spec pending_steady_state_trials_by_team_id([pos_integer()]) :: %{
          pos_integer() => TeamDeletionSchedule.t()
        }
  def pending_steady_state_trials_by_team_id([]), do: %{}

  def pending_steady_state_trials_by_team_id(team_ids) do
    TeamDeletionSchedule
    |> where([sch], sch.team_id in ^team_ids)
    |> where([sch], sch.category == :expired_trial)
    |> where([sch], sch.status == :scheduled)
    |> where([sch], sch.is_backlog == false)
    |> Repo.all()
    |> Map.new(&{&1.team_id, &1})
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

  @spec mark_first_notice_sent(TeamDeletionSchedule.t(), keyword()) :: transition_result
  def mark_first_notice_sent(schedule, opts \\ [])

  def mark_first_notice_sent(%TeamDeletionSchedule{is_backlog: true} = schedule, opts) do
    now = Keyword.get(opts, :now, NaiveDateTime.utc_now(:second))

    transition(
      schedule,
      :first_notice_sent,
      %{first_notice_sent_at: now, deletion_date: DeletionSchedule.backlog_deletion_date(now)},
      opts
    )
  end

  def mark_first_notice_sent(%TeamDeletionSchedule{is_backlog: false} = schedule, opts) do
    now = Keyword.get(opts, :now, NaiveDateTime.utc_now(:second))
    transition(schedule, :first_notice_sent, %{first_notice_sent_at: now}, opts)
  end

  @spec mark_reminder_sent(TeamDeletionSchedule.t(), keyword()) :: transition_result
  def mark_reminder_sent(schedule, opts \\ []) do
    now = Keyword.get(opts, :now, NaiveDateTime.utc_now(:second))
    transition(schedule, :reminder_sent, %{reminder_sent_at: now}, opts)
  end

  @spec mark_completed(TeamDeletionSchedule.t(), keyword()) :: transition_result
  def mark_completed(schedule, opts \\ []) do
    transition(schedule, :completed, %{}, opts)
  end

  @spec cancel(TeamDeletionSchedule.t(), keyword()) :: transition_result
  def cancel(schedule, opts \\ []) do
    transition(schedule, :cancelled, %{}, opts)
  end

  @spec snooze(TeamDeletionSchedule.t(), Date.t(), keyword()) :: transition_result
  def snooze(schedule, until_date, opts \\ []) do
    note = Keyword.get(opts, :note)
    transition(schedule, :snoozed, %{snoozed_until: until_date, snooze_note: note}, opts)
  end

  @doc """
  Unsnoozes a schedule once its snooze has lapsed without the team
  resubscribing. Restarts the notice cycle from scratch
  """
  @spec unsnooze(TeamDeletionSchedule.t(), keyword()) :: transition_result
  def unsnooze(schedule, opts \\ []) do
    today = Keyword.get(opts, :today, Date.utc_today())

    transition(
      schedule,
      :scheduled,
      %{
        is_backlog: true,
        first_notice_due_date: today,
        first_notice_sent_at: nil,
        reminder_sent_at: nil,
        snoozed_until: nil,
        snooze_note: nil
      },
      opts
    )
  end

  @valid_transitions for {from, tos} <- @transitions, to <- tos, do: {from, to}

  defp transition(%TeamDeletionSchedule{status: from} = schedule, to, extra_changes, _opts)
       when {from, to} in @valid_transitions do
    updated =
      schedule
      |> Ecto.Changeset.change(Map.put(extra_changes, :status, to))
      |> Repo.update!()

    {:ok, updated}
  end

  defp transition(%TeamDeletionSchedule{status: from, team_id: team_id}, to, _extra_changes, opts) do
    report_if_invalid? = Keyword.get(opts, :report_if_invalid?, false)

    if report_if_invalid? do
      Sentry.capture_message("Invalid team deletion schedule transition",
        extra: %{from: from, to: to, team_id: team_id}
      )
    end

    {:error, {:invalid_transition, from, to}}
  end

  defp cancel_active_schedule(team_id) do
    {:ok, count} =
      Repo.transact(fn ->
        case active_schedule_for(team_id) do
          nil -> {:ok, 0}
          schedule -> {:ok, cancel_count(schedule)}
        end
      end)

    count
  end

  defp cancel_count(schedule) do
    case cancel(schedule) do
      {:ok, _} -> 1
      {:error, _} -> 0
    end
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
