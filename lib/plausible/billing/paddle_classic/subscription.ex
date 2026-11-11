defmodule Plausible.Billing.PaddleClassic.Subscription do
  @moduledoc false

  use Ecto.Schema

  require Plausible.Billing.Subscription.Status

  import Ecto.Changeset

  alias Plausible.Billing.Subscription

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

  @type t() :: %__MODULE__{}

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
end
