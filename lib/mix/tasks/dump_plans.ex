defmodule Mix.Tasks.DumpPlans do
  @moduledoc """
  This task dumps plan information from the JSON files to the `plans` table in
  PostgreSQL for internal use. This task deletes existing records and
  (re)inserts the list of plans.
  """

  use Mix.Task
  require Logger

  @table "plans"

  def run(_args) do
    Mix.Task.run("app.start")

    Plausible.Repo.delete_all(@table)

    plans =
      Plausible.Billing.Plans.all()
      |> Plausible.Billing.Plans.with_prices()
      |> Enum.map(&Map.from_struct/1)
      |> Enum.map(&prepare_for_dump/1)

    {count, _} = Plausible.Repo.insert_all(@table, plans)

    Logger.info("Inserted #{count} plans")
  end

  defp prepare_for_dump(plan) do
    monthly_cost = plan.monthly_cost && Money.to_decimal(plan.monthly_cost)
    yearly_cost = plan.yearly_cost && Money.to_decimal(plan.yearly_cost)
    {:ok, features} = Plausible.Billing.Ecto.FeatureList.dump(plan.features)
    {:ok, team_member_limit} = Plausible.Billing.Ecto.Limit.dump(plan.team_member_limit)

    plan
    |> Map.drop([:id])
    |> Map.put(:kind, Atom.to_string(plan.kind))
    |> Map.put(:monthly_cost, monthly_cost)
    |> Map.put(:yearly_cost, yearly_cost)
    |> Map.put(:features, features)
    |> Map.put(:team_member_limit, team_member_limit)
  end
end
