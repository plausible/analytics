defmodule Plausible.Billing.Subscription.Status do
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

  Paddle documentation links for reference:

  * Subscription statuses -
    https://developer.paddle.com/classic/reference/zg9joji1mzu0mdi2-subscription-status-reference

  * Payment failures -
    https://developer.paddle.com/classic/guides/zg9joji1mzu0mduy-payment-failures
  """

  defmacro __using__(_opts) do
    quote do
      require Plausible.Billing.Subscription.Status
      alias Plausible.Billing.Subscription
    end
  end

  defmacro active(), do: :active
  defmacro past_due(), do: :past_due
  defmacro paused(), do: :paused
  defmacro deleted(), do: :deleted

  def valid_statuses() do
    [active(), past_due(), paused(), deleted()]
  end
end
