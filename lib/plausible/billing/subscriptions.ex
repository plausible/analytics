defmodule Plausible.Billing.Subscriptions do
  @moduledoc false

  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing.Subscription

  @spec expired?(Subscription.t()) :: boolean()
  @doc """
  Returns whether the given subscription is expired. That means that the
  subscription status is `deleted` and the date until which the customer
  has paid for (i.e. `next_bill_date`) has passed.
  """
  def expired?(subscription)

  def expired?(%Subscription{paddle_plan_id: "free_10k"}), do: false

  def expired?(%Subscription{next_bill_date: next_bill_date} = subscription) do
    deleted? = Subscription.Status.deleted?(subscription)
    expired? = Timex.compare(next_bill_date, Timex.today()) < 0

    deleted? && expired?
  end

  def resumable?(subscription) do
    Subscription.Status.in?(subscription, [
      Subscription.Status.active(),
      Subscription.Status.past_due(),
      Subscription.Status.paused()
    ])
  end

  def halted?(subscription) do
    Subscription.Status.in?(subscription, [
      Subscription.Status.past_due(),
      Subscription.Status.paused()
    ])
  end
end
