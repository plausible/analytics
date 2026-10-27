defmodule Plausible.Billing do
  @moduledoc """
  Billing facade: manual subscriptions, plan change previews, enterprise plan lookup,
  price formatting and notice titles. Subscription lifecycle events coming from the payment
  provider are applied through `Plausible.Billing.SubscriptionState`.
  """
  use Plausible
  use Plausible.Repo

  alias Plausible.Billing.{
    EnterprisePlan,
    PaddleClassic,
    Subscription,
    Subscriptions,
    SubscriptionState
  }

  alias Plausible.Teams

  defmacro allowed_roles(), do: [:owner, :billing]

  @doc """
  Creates a subscription for a custom plan without Paddle checkout (for example, paid by bank transfer).

  The enterprise plan's `paddle_plan_id` is rewritten to a conventional
  `manual-subscription` ID, which is also what the subscription gets, so the two
  stay linked. `paddle_subscription_id` is left empty. See
  `Subscription.manual_changeset/2` for the remaining values.

  ## Limitations for creating a manual subscription:

  * Only the team's latest enterprise plan can be manually subscribed to
  * A team can only have one manual subscription
  * Teams with a resumable (active, past due or paused) Paddle subscription must have it cancelled first.
  * The enterprise plan must have yearly billing
  """
  def create_manual_subscription(team, %{id: plan_id} = enterprise_plan) do
    subscription =
      Repo.one(from(s in Teams.last_subscription_query(), where: s.team_id == ^team.id))

    already_manual? = Subscription.manual_subscription?(subscription)

    already_subscriber? =
      Subscriptions.resumable?(subscription) and subscription.paddle_plan_id != "free_10k"

    latest_plan? = match?(%{id: ^plan_id}, latest_enterprise_plan(team))

    cond do
      already_manual? -> {:error, :already_manual}
      already_subscriber? -> {:error, :active_subscription}
      not latest_plan? -> {:error, :not_latest_plan}
      enterprise_plan.billing_interval != :yearly -> {:error, :not_yearly}
      true -> do_create_manual_subscription(team, enterprise_plan)
    end
  end

  defp do_create_manual_subscription(team, enterprise_plan) do
    Repo.transaction(fn ->
      with {:ok, _plan} <-
             Repo.update(EnterprisePlan.manual_subscription_changeset(enterprise_plan)),
           {:ok, subscription} <- Repo.insert(Subscription.manual_changeset(team)) do
        SubscriptionState.apply_subscription_state(subscription)
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Returns the team's most recently created enterprise plan, or `nil` if it has none.
  """
  def latest_enterprise_plan(team) do
    Repo.one(
      from(ep in Plausible.Billing.EnterprisePlan,
        where: ep.team_id == ^team.id,
        order_by: [desc: ep.inserted_at, desc: ep.id],
        limit: 1
      )
    )
  end

  def change_plan_preview(subscription, new_plan_id) do
    case PaddleClassic.api().update_subscription_preview(
           subscription.paddle_subscription_id,
           new_plan_id
         ) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec format_price(Money.t()) :: String.t()
  def format_price(money) do
    Money.to_string!(money, fractional_digits: 2, no_fraction_if_integer: true)
  end

  def cancelled_subscription_notice_dismiss_id(id) do
    "subscription_cancelled__#{id}"
  end

  def dashboard_locked_notice_title(), do: "Dashboard locked"
  def active_grace_period_notice_title(), do: "You have outgrown your Plausible subscription tier"
  def subscription_cancelled_notice_title(), do: "Subscription cancelled"
  def subscription_past_due_notice_title(), do: "Payment failed"
  def subscription_paused_notice_title(), do: "Subscription paused"
  def pending_site_ownerships_notice_title(), do: "Pending ownership transfers"
end
