defmodule Plausible.Billing.Subscription do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing.Subscription

  @type t() :: %__MODULE__{}

  @required_fields [
    :paddle_subscription_id,
    :paddle_plan_id,
    :update_url,
    :cancel_url,
    :status,
    :next_bill_amount,
    :next_bill_date,
    :currency_code
  ]

  @optional_fields [:last_bill_date]

  @primary_key false
  embedded_schema do
    field :type, Ecto.Enum, values: [:classic, :billing]
    field :id, :integer

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

    field :team_id, :integer

    field :inserted_at, :naive_datetime
  end

  def create_changeset(team, attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> put_assoc(:team, team)
  end

  def changeset(subscription, attrs \\ %{}) do
    subscription
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:paddle_subscription_id)
  end

  @manual_plan_id "manual-subscription"

  @doc """
  The plan ID marking a custom plan as manually subscribed (outside of Paddle).
  """
  def manual_plan_id(), do: @manual_plan_id

  def manual_subscription?(%__MODULE__{paddle_plan_id: @manual_plan_id}), do: true
  def manual_subscription?(_), do: false

  @doc """
  Builds a subscription created manually from the CRM, outside of Paddle.

  There is no known price, so `next_bill_amount` is a `-1` placeholder and
  the UI doesn't present it. The subscription is considered paid today and
  renews in a year.
  """
  def manual_changeset(team, today \\ Date.utc_today()) do
    %__MODULE__{
      paddle_plan_id: @manual_plan_id,
      status: Subscription.Status.active(),
      currency_code: "XXX",
      next_bill_amount: "-1",
      last_bill_date: today,
      next_bill_date: Date.shift(today, year: 1)
    }
    |> change()
    |> put_assoc(:team, team)
  end

  def free(team, attrs \\ %{}) do
    %__MODULE__{
      paddle_plan_id: "free_10k",
      status: Subscription.Status.active(),
      next_bill_amount: "0",
      currency_code: "EUR"
    }
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> put_assoc(:team, team)
    |> unique_constraint(:paddle_subscription_id)
  end
end
