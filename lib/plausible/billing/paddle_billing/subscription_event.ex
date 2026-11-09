defmodule Plausible.Billing.PaddleBilling.SubscriptionEvent do
  @moduledoc """
  Schema representing processed Paddle Billing events.
  """

  use Ecto.Schema

  @statuses [:active, :past_due, :paused, :canceled]

  @event_types [:"subscription.created", :"subscription.updated"]

  @type status() :: unquote(Enum.reduce(@statuses, &{:|, [], [&1, &2]}))

  schema "billing_subscription_events" do
    field :billing_event_id, :string

    field :billing_subscription_id, :string
    field :billing_customer_id, :string
    field :billing_product_id, :string
    field :billing_price_id, :string
    field :next_bill_amount, :string
    field :next_bill_date, :date
    field :last_bill_date, :date
    field :currency_code, :string
    field :status, Ecto.Enum, values: @statuses

    field :original_event_type, Ecto.Enum, values: @event_types
    field :original_event, :map
    field :occurred_at, :naive_datetime_usec

    belongs_to :team, Plausible.Teams.Team

    timestamps()
  end
end
