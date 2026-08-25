defmodule Plausible.TeamDeletionSchedules do
  @moduledoc """
  Context for scheduling inactive teams deletion (trial or subscription expired).
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
          where:
            fragment("coalesce((?->>'manual_lock')::boolean, false)", field(t, :grace_period)) ==
              false,
          where: exists(from(s in Site.regular(), where: s.team_id == parent_as(:team).id)),
          where:
            (is_nil(s.id) and not is_nil(t.trial_expiry_date) and t.trial_expiry_date < ^today) or
              (not is_nil(s.id) and
                 s.status in [^Subscription.Status.deleted(), ^Subscription.Status.paused()] and
                 s.paddle_plan_id != "free_10k" and s.next_bill_date < ^today),
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
      {count, _} =
        Repo.update_all(
          from(sch in TeamDeletionSchedule,
            where: sch.team_id == ^team.id,
            where: sch.status in ^TeamDeletionSchedule.active_statuses()
          ),
          set: [status: :cancelled, updated_at: NaiveDateTime.utc_now(:second)]
        )

      count
    else
      0
    end
  end

  defp terminal_statuses_index_predicate do
    values = Enum.map_join(TeamDeletionSchedule.terminal_statuses(), ", ", &"'#{&1}'")
    "(team_id) WHERE status NOT IN (#{values})"
  end

  defp build_schedule_row(candidate, today, now) do
    {category, expiry_date} =
      if candidate.has_subscription? do
        {:expired_subscription, candidate.next_bill_date}
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
