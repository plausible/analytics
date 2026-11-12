defmodule Plausible.Billing.Subscription do
  @moduledoc false

  use Ecto.Schema

  alias Plausible.Billing.Subscription

  @type t() :: %__MODULE__{}

  schema "all_subscriptions" do
    field :type, Ecto.Enum, values: [:classic, :billing], default: :classic

    # Classic specific fields
    field :paddle_subscription_id, :string
    field :paddle_plan_id, :string
    field :update_url, :string
    field :cancel_url, :string

    # Billing specific fields
    field :billing_subscription_id, :string
    field :billing_customer_id, :string
    field :billing_product_id, :string
    field :billing_price_id, :string

    # Common fields
    field :next_bill_amount, :string
    field :next_bill_date, :date
    field :last_bill_date, :date
    field :currency_code, :string
    field :status, Ecto.Enum, values: Subscription.Status.valid_statuses()

    belongs_to :team, Plausible.Teams.Team

    timestamps()
  end

  @manual_plan_id "manual-subscription"

  @doc """
  The plan ID marking a custom plan as manually subscribed (outside of Paddle).
  """
  def manual_plan_id(), do: @manual_plan_id

  def manual_subscription?(%__MODULE__{paddle_plan_id: @manual_plan_id}), do: true
  def manual_subscription?(_), do: false
end
