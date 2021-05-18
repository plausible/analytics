defmodule Plausible.Billing.Subscription do
  use Ecto.Schema
  import Ecto.Changeset

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
      next_bill_amount: "0"
    }
    |> cast(attrs, @required_fields)
    |> validate_required([:user_id])
    |> validate_inclusion(:status, @valid_statuses)
    |> unique_constraint(:paddle_subscription_id)
  end
end
