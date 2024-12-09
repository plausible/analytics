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
    # :team_id,
    :currency_code
  ]

  # @optional_fields [:last_bill_date, :team_id, :user_id]
  @optional_fields [:last_bill_date, :team_id]

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

    # belongs_to :user, Plausible.Auth.User
    belongs_to :team, Plausible.Teams.Team

    timestamps()
  end

  def changeset(model, attrs \\ %{}) do
    model
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:paddle_subscription_id)
  end

  def free(attrs \\ %{}) do
    %__MODULE__{
      paddle_plan_id: "free_10k",
      status: Subscription.Status.active(),
      next_bill_amount: "0",
      currency_code: "EUR"
    }
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required([:user_id])
    |> unique_constraint(:paddle_subscription_id)
  end
end
