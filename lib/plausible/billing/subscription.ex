defmodule Plausible.Billing.Subscription do
  use Ecto.Schema
  import Ecto.Changeset

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

  @type t() :: %__MODULE__{}

  @required_fields [
    :paddle_subscription_id,
    :paddle_plan_id,
    :update_url,
    :cancel_url,
    :status,
    :next_bill_amount,
    :next_bill_date,
    :user_id,
    :currency_code
  ]

  @optional_fields [:last_bill_date]

  @valid_statuses ["active", "past_due", "deleted", "paused"]

  schema "subscriptions" do
    field :paddle_subscription_id, :string
    field :paddle_plan_id, :string
    field :update_url, :string
    field :cancel_url, :string
    field :status, :string
    field :next_bill_amount, :string
    field :next_bill_date, :date
    field :last_bill_date, :date
    field :currency_code, :string

    belongs_to :user, Plausible.Auth.User

    timestamps()
  end

  def changeset(model, attrs \\ %{}) do
    model
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, @valid_statuses)
    |> unique_constraint(:paddle_subscription_id)
  end

  def free(attrs \\ %{}) do
    %__MODULE__{
      paddle_plan_id: "free_10k",
      status: "active",
      next_bill_amount: "0",
      currency_code: "EUR"
    }
    |> cast(attrs, @required_fields)
    |> validate_required([:user_id])
    |> validate_inclusion(:status, @valid_statuses)
    |> unique_constraint(:paddle_subscription_id)
  end
end
