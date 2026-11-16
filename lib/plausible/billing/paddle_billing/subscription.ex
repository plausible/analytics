defmodule Plausible.Billing.PaddleBilling.Subscription do
  @moduledoc """
  Schema representing Paddle Billing subscription.

  Only at most a single subscription can exist per team, at all times.
  """

  use Ecto.Schema

  alias Plausible.Billing.Subscription.Status

  schema "billing_subscriptions" do
    field :billing_subscription_id, :string
    field :billing_customer_id, :string
    field :billing_product_id, :string
    field :billing_price_id, :string
    field :next_bill_amount, :string
    field :next_bill_date, :date
    field :last_bill_date, :date
    field :currency_code, :string
    field :status, Ecto.Enum, values: Status.valid_statuses()

    belongs_to :team, Plausible.Teams.Team

    timestamps()
  end
end
