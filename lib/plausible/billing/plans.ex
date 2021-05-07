defmodule Plausible.Billing.Plans do
  @plans_v1 [
    %{
      limit: 10_000,
      monthly_product_id: "558018",
      monthly_cost: "$6",
      yearly_product_id: "572810",
      yearly_cost: "$48"
    },
    %{
      limit: 100_000,
      monthly_product_id: "558745",
      monthly_cost: "$12",
      yearly_product_id: "590752",
      yearly_cost: "$96"
    },
    %{
      limit: 200_000,
      monthly_product_id: "597485",
      monthly_cost: "$18",
      yearly_product_id: "597486",
      yearly_cost: "$144"
    },
    %{
      limit: 500_000,
      monthly_product_id: "597487",
      monthly_cost: "$27",
      yearly_product_id: "597488",
      yearly_cost: "$216"
    },
    %{
      limit: 1_000_000,
      monthly_product_id: "597642",
      monthly_cost: "$48",
      yearly_product_id: "597643",
      yearly_cost: "$384"
    },
    %{
      limit: 2_000_000,
      monthly_product_id: "597309",
      monthly_cost: "$69",
      yearly_product_id: "597310",
      yearly_cost: "$552"
    },
    %{
      limit: 5_000_000,
      monthly_product_id: "597311",
      monthly_cost: "$99",
      yearly_product_id: "597312",
      yearly_cost: "$792"
    },
    %{
      limit: 10_000_000,
      monthly_product_id: "642352",
      monthly_cost: "$150",
      yearly_product_id: "642354",
      yearly_cost: "$1200"
    },
    %{
      limit: 20_000_000,
      monthly_product_id: "642355",
      monthly_cost: "$225",
      yearly_product_id: "642356",
      yearly_cost: "$1800"
    },
    %{
      limit: 50_000_000,
      monthly_product_id: "650652",
      monthly_cost: "$330",
      yearly_product_id: "650653",
      yearly_cost: "$2640"
    }
  ]

  @unlisted_plans_v1 [
    %{limit: 150_000_000, yearly_product_id: "648089", yearly_cost: "$4800"}
  ]

  def plans_for(user) do
    @plans_v1 |> Enum.map(fn plan -> Map.put(plan, :volume, number_format(plan[:limit])) end)
  end

  def all_yearly_plan_ids do
    Enum.map(@plans_v1, fn plan -> plan[:yearly_product_id] end)
  end

  def for_product_id(product_id) do
    Enum.find(@plans_v1 ++ @unlisted_plans_v1, fn plan ->
      product_id in [plan[:monthly_product_id], plan[:yearly_product_id]]
    end)
  end

  def subscription_quota("free_10k"), do: "10k"

  def subscription_quota(product_id) do
    case for_product_id(product_id) do
      nil -> raise "Unknown quota for subscription #{product_id}"
      product -> number_format(product[:limit])
    end
  end

  def subscription_interval("free_10k"), do: "N/A"

  def subscription_interval(product_id) do
    case for_product_id(product_id) do
      nil ->
        raise "Unknown interval for subscription #{product_id}"

      plan ->
        if product_id == plan[:monthly_product_id] do
          "monthly"
        else
          "yearly"
        end
    end
  end

  def allowance(%Plausible.Billing.Subscription{paddle_plan_id: "free_10k"}), do: 10_000

  def allowance(subscription) do
    found = for_product_id(subscription.paddle_plan_id)

    if found do
      Map.fetch!(found, :limit)
    end
  end

  def suggested_plan(user, usage) do
    Enum.find(plans_for(user), fn plan -> usage < plan[:limit] end)
  end

  defp number_format(num) do
    PlausibleWeb.StatsView.large_number_format(num)
  end
end
