defmodule Plausible.Billing.Subscriptions do
  alias Plausible.Billing.{Subscription, Plan, Plans}

  @moduledoc """
  The subscription statuses are stored in Paddle. They can only be changed
  through Paddle webhooks, which always send the current subscription status
  via the payload.

  * `active` - All good with the payments. Can access stats.

  * `past_due` - The payment has failed, but we're trying to charge the customer
    again. Access to stats is still granted. There will be three retries - after
    3, 5, and 7 days have passed from the first failure. After a failure on the
    final retry, the subscription status will change to `paused`. As soon as the
    customer updates their billing details, Paddle will charge them again, and
    after a successful payment, the subscription will become `active` again.

  * `paused` - we've tried to charge the customer but all the retries have failed.
    Stats access restricted. As soon as the customer updates their billing details,
    Paddle will charge them again, and after a successful payment, the subscription
    will become `active` again.

  * `deleted` - The customer has triggered the cancel subscription action. Access
    to stats should be granted for the time the customer has already paid for. If
    they want to upgrade again, new billing details have to be provided.

  # Paddle documentation links for reference

    * Subscription statuses -
      https://developer.paddle.com/classic/reference/zg9joji1mzu0mdi2-subscription-status-reference

    * Payment failures -
      https://developer.paddle.com/classic/guides/zg9joji1mzu0mduy-payment-failures
  """

  @valid_statuses ["active", "past_due", "deleted", "paused"]

  def valid_statuses(), do: @valid_statuses

  def expired?(%Subscription{paddle_plan_id: "free_10k"}), do: false

  def expired?(%Subscription{status: status, next_bill_date: next_bill_date}) do
    cancelled? = status == "deleted"
    expired? = Timex.compare(next_bill_date, Timex.today()) < 0

    cancelled? && expired?
  end

  def business_tier?(%Subscription{} = subscription) do
    case Plans.get_subscription_plan(subscription) do
      %Plan{kind: :business} -> true
      _ -> false
    end
  end
end
