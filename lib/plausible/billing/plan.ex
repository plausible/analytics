defmodule Plausible.Billing.Plan do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  embedded_schema do
    # Due to grandfathering, we sometimes need to check the "generation" (e.g.
    # v1, v2, etc...) of a user's subscription plan. For instance, on prod, the
    # users subscribed to a v2 plan are only supposed to see v2 plans when they
    # go to the upgrade page.
    #
    # In the `dev` environment though, "sandbox" plans are used, which unlike
    # production plans, contain multiple generations of plans in the same file
    # for testing purposes.
    field :generation, :integer
    field :kind, Ecto.Enum, values: [:starter, :growth, :business]

    field :features, Plausible.Billing.Ecto.FeatureList
    field :monthly_pageview_limit, :integer
    field :site_limit, :integer
    field :team_member_limit, Plausible.Billing.Ecto.Limit
    field :volume, :string
    field :data_retention_in_years, :integer

    field :monthly_cost
    field :monthly_product_id, :string
    field :yearly_cost
    field :yearly_product_id, :string
  end

  @required_fields ~w(generation kind features monthly_pageview_limit site_limit team_member_limit volume)a
  @optional_fields ~w(monthly_cost yearly_cost monthly_product_id yearly_product_id data_retention_in_years)a
  @fields @required_fields ++ @optional_fields

  def changeset(plan, attrs) do
    plan
    |> cast(attrs, @fields)
    |> put_volume()
    |> validate_required_either([:monthly_product_id, :yearly_product_id])
    |> validate_required(@required_fields)
  end

  defp put_volume(changeset) do
    if volume = get_field(changeset, :monthly_pageview_limit) do
      put_change(changeset, :volume, PlausibleWeb.StatsView.large_number_format(volume))
    else
      changeset
    end
  end

  def validate_required_either(changeset, fields) do
    if Enum.any?(fields, &get_field(changeset, &1)) do
      changeset
    else
      add_error(changeset, hd(fields), "one of these fields must be present #{inspect(fields)}")
    end
  end
end
