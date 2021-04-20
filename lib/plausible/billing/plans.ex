defmodule Plausible.Billing.Plans do
  @monthly_plans [
    %{product_id: "558018", cost: "$6", limit: 10_000, cycle: "monthly"},
    %{product_id: "558745", cost: "$12", limit: 100_000, cycle: "monthly"},
    %{product_id: "597485", cost: "$18", limit: 200_000, cycle: "monthly"},
    %{product_id: "597487", cost: "$27", limit: 500_000, cycle: "monthly"},
    %{product_id: "597642", cost: "$48", limit: 1_000_000, cycle: "monthly"},
    %{product_id: "597309", cost: "$69", limit: 2_000_000, cycle: "monthly"},
    %{product_id: "597311", cost: "$99", limit: 5_000_000, cycle: "monthly"},
    %{product_id: "642352", cost: "$150", limit: 10_000_000, cycle: "monthly"},
    %{product_id: "642355", cost: "$225", limit: 20_000_000, cycle: "monthly"},
    %{product_id: "650652", cost: "$330", limit: 50_000_000, cycle: "monthly"}
  ]

  @yearly_plans [
    %{product_id: "572810", cost: "$48", monthly_cost: "$4", limit: 10_000, cycle: "yearly"},
    %{product_id: "590752", cost: "$96", monthly_cost: "$8", limit: 100_000, cycle: "yearly"},
    %{product_id: "597486", cost: "$144", monthly_cost: "$12", limit: 200_000, cycle: "yearly"},
    %{product_id: "597488", cost: "$216", monthly_cost: "$18", limit: 500_000, cycle: "yearly"},
    %{product_id: "597643", cost: "$384", monthly_cost: "$32", limit: 1_000_000, cycle: "yearly"},
    %{product_id: "597310", cost: "$552", monthly_cost: "$46", limit: 2_000_000, cycle: "yearly"},
    %{product_id: "597312", cost: "$792", monthly_cost: "$66", limit: 5_000_000, cycle: "yearly"},
    %{
      product_id: "642354",
      cost: "$1200",
      monthly_cost: "$100",
      limit: 10_000_000,
      cycle: "yearly"
    },
    %{
      product_id: "642356",
      cost: "$1800",
      monthly_cost: "$150",
      limit: 20_000_000,
      cycle: "yearly"
    },
    %{
      product_id: "650653",
      cost: "$2640",
      monthly_cost: "$220",
      limit: 50_000_000,
      cycle: "yearly"
    },
    %{
      product_id: "648089",
      cost: "$4800",
      monthly_cost: "$400",
      limit: 150_000_000,
      cycle: "yearly"
    }
  ]

  @all_plans @monthly_plans ++ @yearly_plans

  def plans do
    monthly =
      @monthly_plans
      |> Enum.map(fn plan -> {String.to_atom(number_format(plan[:limit])), plan} end)
      |> Enum.into(%{})

    yearly =
      @yearly_plans
      |> Enum.map(fn plan -> {String.to_atom(number_format(plan[:limit])), plan} end)
      |> Enum.into(%{})

    %{
      monthly: monthly,
      yearly: yearly
    }
  end

  def yearly_plan_ids do
    Enum.map(@yearly_plans, fn plan -> plan[:product_id] end)
  end

  def for_product_id(product_id) do
    Enum.find(@all_plans, fn plan -> plan[:product_id] == product_id end)
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
      nil -> raise "Unknown interval for subscription #{product_id}"
      product -> product[:cycle]
    end
  end

  def suggested_plan_name(usage) do
    plan = suggested_plan(usage)
    number_format(plan[:limit]) <> "/mo"
  end

  def suggested_plan_cost(usage) do
    plan = suggested_plan(usage)
    plan[:cost] <> "/mo"
  end

  def suggested_plan_cost_yearly(usage) do
    plan = Enum.find(@yearly_plans, fn plan -> usage < plan[:limit] end)
    plan[:monthly_cost] <> "/mo"
  end

  defp suggested_plan(usage) do
    Enum.find(@monthly_plans, fn plan -> usage < plan[:limit] end)
  end

  def allowance(subscription) do
    found = Enum.find(@all_plans, fn plan -> plan[:product_id] == subscription.paddle_plan_id end)

    if found do
      Map.fetch!(found, :limit)
    end
  end

  defp number_format(num) do
    PlausibleWeb.StatsView.large_number_format(num)
  end
end
