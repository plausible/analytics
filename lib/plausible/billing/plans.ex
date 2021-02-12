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
    %{product_id: "642355", cost: "$225", limit: 20_000_000, cycle: "monthly"}
  ]

  @yearly_plans [
    %{product_id: "572810", cost: "$48", limit: 10_000, cycle: "yearly"},
    %{product_id: "590752", cost: "$96", limit: 100_000, cycle: "yearly"},
    %{product_id: "597486", cost: "$144", limit: 200_000, cycle: "yearly"},
    %{product_id: "597488", cost: "$216", limit: 500_000, cycle: "yearly"},
    %{product_id: "597643", cost: "$384", limit: 1_000_000, cycle: "yearly"},
    %{product_id: "597310", cost: "$552", limit: 2_000_000, cycle: "yearly"},
    %{product_id: "597312", cost: "$792", limit: 5_000_000, cycle: "yearly"},
    %{product_id: "642354", cost: "$1200", limit: 10_000_000, cycle: "yearly"},
    %{product_id: "642356", cost: "$1800", limit: 20_000_000, cycle: "yearly"}
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

  def suggested_plan_name(usage) do
    plan = suggested_plan(usage)
    number_format(plan[:limit]) <> "/mo"
  end

  def suggested_plan_cost(usage) do
    plan = suggested_plan(usage)
    plan[:cost] <> "/mo"
  end

  defp suggested_plan(usage) do
    Enum.find(@monthly_plans, fn plan -> usage < plan[:limit] end)
  end

  def allowance(subscription) do
    Enum.find(@all_plans, fn plan -> plan[:product_id] == subscription.paddle_plan_id end)
    |> Map.fetch!(:limit)
  end

  defp number_format(num) do
    PlausibleWeb.StatsView.large_number_format(num)
  end
end
