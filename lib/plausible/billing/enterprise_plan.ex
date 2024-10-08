defmodule Plausible.Billing.EnterprisePlan do
  use Ecto.Schema
  import Ecto.Changeset

  @required_fields [
    :user_id,
    :paddle_plan_id,
    :billing_interval,
    :monthly_pageview_limit,
    :hourly_api_request_limit,
    :site_limit,
    :features,
    :team_member_limit
  ]

  @optional_fields [
    :team_id
  ]

  schema "enterprise_plans" do
    field :paddle_plan_id, :string
    field :billing_interval, Ecto.Enum, values: [:monthly, :yearly]
    field :monthly_pageview_limit, :integer
    field :site_limit, :integer
    field :team_member_limit, Plausible.Billing.Ecto.Limit
    field :features, Plausible.Billing.Ecto.FeatureList, default: []
    field :hourly_api_request_limit, :integer

    belongs_to :user, Plausible.Auth.User
    belongs_to :team, Plausible.Teams.Team

    timestamps()
  end

  def changeset(model, attrs \\ %{}) do
    model
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:user_id)
  end
end
