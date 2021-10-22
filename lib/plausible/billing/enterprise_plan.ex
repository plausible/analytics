defmodule Plausible.Billing.EnterprisePlan do
  use Ecto.Schema
  import Ecto.Changeset

  @required_fields [
    :user_id,
    :paddle_plan_id,
    :billing_interval,
    :monthly_pageview_limit,
    :hourly_api_request_limit,
    :site_limit
  ]

  schema "enterprise_plans" do
    field :paddle_plan_id, :string
    field :billing_interval, Ecto.Enum, values: [:monthly, :yearly]
    field :monthly_pageview_limit, :integer
    field :hourly_api_request_limit, :integer
    field :site_limit, :integer

    belongs_to :user, Plausible.Auth.User

    timestamps()
  end

  def changeset(model, attrs \\ %{}) do
    model
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:user_id)
  end
end
