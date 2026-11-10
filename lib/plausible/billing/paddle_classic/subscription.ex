defmodule Plausible.Billing.PaddleClassic.Subscription do
  @moduledoc false

  use Ecto.Schema

  require Plausible.Billing.Subscription.Status

  alias Plausible.Billing.Subscription

  schema "subscriptions" do
    field :paddle_subscription_id, :string
    field :paddle_plan_id, :string
    field :update_url, :string
    field :cancel_url, :string
    field :status, Ecto.Enum, values: Subscription.Status.valid_statuses()
    field :next_bill_amount, :string
    field :next_bill_date, :date
    field :last_bill_date, :date
    field :currency_code, :string

    belongs_to :team, Plausible.Teams.Team

    timestamps()
  end
end
