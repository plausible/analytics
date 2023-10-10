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

  def expired?(%Subscription{status: status, next_bill_date: next_bill_date}) do
    cancelled? = status == Subscription.Status.deleted()
    expired? = Timex.compare(next_bill_date, Timex.today()) < 0

    cancelled? && expired?
  end

  def resumable?(nil), do: false

  def resumable?(%Subscription{status: status}) do
    status in [
      Subscription.Status.active(),
      Subscription.Status.past_due(),
      Subscription.Status.paused()
    ]
  end
end
