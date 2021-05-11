defmodule Plausible.Billing.Plans do
  @plans_v1 File.read!(Application.app_dir(:plausible) <> "/priv/plans_v1.json")
            |> Jason.decode!(keys: :atoms)
  @plans_v2 File.read!(Application.app_dir(:plausible) <> "/priv/plans_v2.json")
            |> Jason.decode!(keys: :atoms)

  @unlisted_plans_v1 [
    %{limit: 150_000_000, yearly_product_id: "648089", yearly_cost: "$4800"}
  ]

  @v2_pricing_date ~D[2021-05-11]

  def plans_for(user) do
    raw_plans =
      if Timex.before?(user.inserted_at, @v2_pricing_date) do
        @plans_v1
      else
        @plans_v2
      end

    Enum.map(raw_plans, fn plan -> Map.put(plan, :volume, number_format(plan[:limit])) end)
  end

  def all_yearly_plan_ids do
    Enum.map(all_plans(), fn plan -> plan[:yearly_product_id] end)
  end

  def for_product_id(product_id) do
    Enum.find(all_plans(), fn plan ->
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

  defp all_plans() do
    @plans_v1 ++ @unlisted_plans_v1 ++ @plans_v2
  end
end
