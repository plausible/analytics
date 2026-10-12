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
    field :features, {:array, Plausible.Billing.Ecto.Feature}, default: []
    field :hourly_api_request_limit, :integer
    field :managed_proxy_price_modifier, :boolean, default: false, virtual: true

    belongs_to :team, Plausible.Teams.Team

    timestamps()
  end

  @max round(:math.pow(2, 31))

  def create_changeset(model, attrs \\ %{}) do
    model
    |> cast(attrs, @required_fields)
    |> validate()
  end

  @doc """
  Updates an existing plan. `paddle_plan_id` is never changed, because
  subscriptions are linked to the plan by it.
  """
  def update_changeset(plan, attrs \\ %{}) do
    plan
    |> cast(attrs, List.delete(@required_fields, :paddle_plan_id))
    |> validate()
  end

  @doc """
  Marks the plan as manually subscribed to, see
  `Plausible.Billing.create_manual_subscription/2`.
  """
  def manual_subscription_changeset(plan) do
    plan
    |> change(paddle_plan_id: Plausible.Billing.Subscription.manual_plan_id())
    |> unique_paddle_plan_id_constraint()
  end

  defp validate(changeset) do
    changeset
    |> validate_number(:monthly_pageview_limit, less_than: @max)
    |> validate_number(:site_limit, less_than: @max)
    |> validate_number(:hourly_api_request_limit, less_than: @max)
    |> validate_required(@required_fields)
    |> unique_paddle_plan_id_constraint()
  end

  defp unique_paddle_plan_id_constraint(changeset) do
    unique_constraint(changeset, [:team_id, :paddle_plan_id], error_key: :paddle_plan_id)
  end
end
