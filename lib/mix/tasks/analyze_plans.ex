defmodule Mix.Tasks.AnalyzePlans do
  use Mix.Task
  use Plausible.Repo

  # coveralls-ignore-start

  def run(_) do
    Mix.Task.run("app.start")

    res =
      Repo.all(
        from s in Plausible.Billing.Subscription,
          where: s.status == "active",
          group_by: s.paddle_plan_id,
          select: {s.paddle_plan_id, count(s)}
      )

    res =
      Enum.map(res, fn {plan_id, count} ->
        plan = Plausible.Billing.Plans.find(plan_id)

        if plan do
          is_monthly = plan_id == plan.monthly_product_id

          monthly_revenue =
            if is_monthly do
              price(plan.monthly_cost)
            else
              price(plan.yearly_cost) / 12
            end

          {PlausibleWeb.StatsView.large_number_format(plan.limit), monthly_revenue, count}
        end
      end)
      |> Enum.filter(& &1)

    res =
      Enum.reduce(res, %{}, fn {limit, revenue, count}, acc ->
        total_revenue = revenue * count

        Map.update(acc, limit, {total_revenue, count}, fn {ex_rev, ex_count} ->
          {ex_rev + total_revenue, ex_count + count}
        end)
      end)

    total_revenue = round(Enum.reduce(res, 0, fn {_, {revenue, _}}, sum -> sum + revenue end))

    for {limit, {rev, _}} <- res do
      percentage = round(rev / total_revenue * 100)

      IO.puts(
        "The #{limit} plan makes up #{percentage}% of total revenue ($#{round(rev)} / $#{total_revenue})"
      )
    end
  end

  defp price("$" <> nr) do
    String.to_integer(nr)
  end
end
