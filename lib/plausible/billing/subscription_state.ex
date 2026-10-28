defmodule Plausible.Billing.SubscriptionState do
  @moduledoc """
  Provider-independent application of subscription state changes.

  Payment providers (currently Paddle Classic, later Paddle Billing) parse
  their own webhook payloads into plain subscription attributes and call the
  functions here to persist them and bring the team's state in line: traffic
  acceptance, grace period, site locking, scheduled deletion and API limits.

  The functions expect to be called inside a transaction opened by the caller.
  """
  use Plausible.Repo

  alias Plausible.Billing.{EnterprisePlan, SiteLocker, Subscription}
  alias Plausible.TeamDeletionSchedules
  alias Plausible.Teams

  @doc """
  Inserts a new subscription for the team and applies the resulting state.

  When a subscription with the same `paddle_subscription_id` already exists
  (a duplicate delivery), nothing is inserted and the existing subscription is
  returned, after reporting to Sentry if the incoming data differs from it.
  """
  def create(team, attrs) do
    changeset = Subscription.create_changeset(team, attrs)

    case Repo.insert(changeset,
           on_conflict: :nothing,
           conflict_target: :paddle_subscription_id
         ) do
      {:ok, %{id: nil}} ->
        handle_conflict("subscription_created", attrs.paddle_subscription_id, changeset)

      {:ok, subscription} ->
        apply_subscription_state(subscription)
    end
  end

  @doc """
  Updates an existing subscription and applies the resulting state.
  """
  def update(subscription, attrs) do
    subscription
    |> Subscription.changeset(attrs)
    |> Repo.update!()
    |> apply_subscription_state()
  end

  @doc """
  Records the subscription's cancellation (the `status` in `attrs`) and
  notifies the team's owners and billing members. Nothing is locked or
  limited here: the team keeps the plan until `next_bill_date`.
  """
  def cancel(subscription, attrs) do
    subscription = Repo.preload(subscription, team: [:owners, :billing_members])

    updated =
      subscription
      |> Subscription.changeset(attrs)
      |> Repo.update!()

    for recipient <- subscription.team.owners ++ subscription.team.billing_members do
      recipient
      |> PlausibleWeb.Email.cancellation_email()
      |> Plausible.Mailer.send()
    end

    updated
  end

  @doc """
  Records the billing dates and amount after a successful payment, and makes
  sure the team accepts traffic and isn't scheduled for deletion.
  """
  def record_payment(subscription, attrs) do
    subscription =
      subscription
      |> Subscription.changeset(attrs)
      |> Repo.update!()
      |> Repo.preload(:team)

    Teams.update_accept_traffic_until(subscription.team)
    TeamDeletionSchedules.cancel_for_team(subscription.team)

    subscription
  end

  @doc """
  Brings the team's state in line with its current subscription. Returns the team.
  """
  def apply_subscription_state(subscription) do
    team =
      Teams.Team
      |> Repo.get!(subscription.team_id)
      |> Teams.with_subscription()
      |> Repo.preload(:owners)

    if subscription.id != team.subscription.id do
      Sentry.capture_message("Susbscription ID mismatch",
        extra: %{subscription: inspect(subscription), team_id: team.id}
      )
    end

    team
    |> Teams.update_accept_traffic_until()
    |> Teams.remove_grace_period()
    |> Teams.maybe_reset_next_upgrade_override()
    |> tap(&SiteLocker.update_for/1)
    |> tap(&TeamDeletionSchedules.cancel_for_team/1)
    |> maybe_adjust_api_key_limits()
  end

  defp maybe_adjust_api_key_limits(team) do
    plan =
      Repo.get_by(EnterprisePlan,
        team_id: team.id,
        paddle_plan_id: team.subscription.paddle_plan_id
      )

    if plan do
      Repo.update_all(
        from(t in Teams.Team, where: t.id == ^team.id),
        set: [hourly_api_request_limit: plan.hourly_api_request_limit]
      )
    end

    team
  end

  defp handle_conflict(webhook_type, paddle_subscription_id, changeset) do
    existing = Repo.get_by!(Subscription, paddle_subscription_id: paddle_subscription_id)

    diff = changeset_diff(changeset, existing)

    if diff != %{} do
      Sentry.capture_message(
        "Duplicate #{webhook_type} webhook for paddle_subscription_id=#{existing.paddle_subscription_id}.",
        extra: %{
          paddle_subscription_id: existing.paddle_subscription_id,
          team_id: existing.team_id,
          diff: diff
        }
      )
    end

    existing
  end

  defp changeset_diff(%Ecto.Changeset{changes: changes}, existing) do
    for {key, incoming_val} <- changes,
        not is_struct(incoming_val, Ecto.Changeset),
        existing_val = Map.get(existing, key),
        existing_val != incoming_val,
        into: %{},
        do: {key, %{existing: existing_val, incoming: incoming_val}}
  end
end
