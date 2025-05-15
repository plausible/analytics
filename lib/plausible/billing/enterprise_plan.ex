defmodule Plausible.Billing.EnterprisePlan do
  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @required_fields [
    :team_id,
    :paddle_plan_id,
    :billing_interval,
    :monthly_pageview_limit,
    :hourly_api_request_limit,
    :site_limit,
    :features,
    :team_member_limit
  ]

  schema "enterprise_plans" do
    field :paddle_plan_id, :string
    field :billing_interval, Ecto.Enum, values: [:monthly, :yearly]
    field :monthly_pageview_limit, :integer
    field :site_limit, :integer
    field :team_member_limit, Plausible.Billing.Ecto.Limit
    field :features, Plausible.Billing.Ecto.FeatureList, default: []
    field :hourly_api_request_limit, :integer

    belongs_to :team, Plausible.Teams.Team

    timestamps()
  end

  @max round(:math.pow(2, 31))

  def changeset(model, attrs \\ %{}) do
    model
    |> cast(attrs, @required_fields)
    |> validate_number(:monthly_pageview_limit, less_than: @max)
    |> validate_number(:site_limit, less_than: @max)
    |> validate_number(:hourly_api_request_limit, less_than: @max)
    |> validate_required(@required_fields)
  end
end
