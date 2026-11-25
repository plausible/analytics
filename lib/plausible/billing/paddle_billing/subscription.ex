defmodule Plausible.Billing.PaddleBilling.Subscription do
  @moduledoc """
  Schema representing Paddle Billing subscription.

  A team has at most one live (active, past due or paused) subscription at a time.
  Cancelled subscriptions are kept, so their later events still find them.
  """

  use Ecto.Schema

  alias Plausible.Billing.Subscription.Status

  import Ecto.Changeset

  @required_fields [
    :billing_subscription_id,
    :billing_customer_id,
    :billing_product_id,
    :billing_price_id,
    :billing_interval,
    :next_bill_amount,
    :next_bill_date,
    :currency_code,
    :status
  ]

  @optional_fields [:last_bill_date]

  schema "billing_subscriptions" do
    field :billing_subscription_id, :string
    field :billing_customer_id, :string
    field :billing_product_id, :string
    field :billing_price_id, :string
    field :billing_interval, Ecto.Enum, values: [:monthly, :yearly]
    field :next_bill_amount, :string
    field :next_bill_date, :date
    field :last_bill_date, :date
    field :currency_code, :string
    field :status, Ecto.Enum, values: Status.valid_statuses()

    belongs_to :team, Plausible.Teams.Team

    timestamps()
  end

  @spec fields() :: [atom()]
  def fields(), do: @required_fields ++ @optional_fields

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, fields())
    |> validate_required(@required_fields)
    |> unique_constraint(:billing_subscription_id)
    |> unique_constraint(:team_id, name: :billing_subscriptions_live_team_id_index)
  end
end
