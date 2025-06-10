defmodule Plausible.Billing.EnterprisePlanTest do
  use Plausible.DataCase
  use Plausible.Teams.Test
  alias Plausible.Billing.EnterprisePlan

  test "changeset/2 loads and dumps the list of features" do
    team = new_user(trial_expiry_date: Date.utc_today()) |> team_of()
    plan = build(:enterprise_plan, team_id: team.id)
    attrs = %{features: ["props", "stats_api"]}

    assert {:ok, enterprise_plan} =
             plan
             |> EnterprisePlan.changeset(attrs)
             |> Plausible.Repo.insert()

    assert %EnterprisePlan{
             features: [Plausible.Billing.Feature.Props, Plausible.Billing.Feature.StatsAPI]
           } = enterprise_plan

    assert %EnterprisePlan{
             features: [Plausible.Billing.Feature.Props, Plausible.Billing.Feature.StatsAPI]
           } = Plausible.Repo.get(EnterprisePlan, enterprise_plan.id)
  end

  test "changeset/2 fails when feature does not exist" do
    team = new_user(trial_expiry_date: Date.utc_today()) |> team_of()
    plan = build(:enterprise_plan, team_id: team.id)
    attrs = %{features: ["ga4_import"]}

    assert {:error, changeset} =
             plan
             |> EnterprisePlan.changeset(attrs)
             |> Plausible.Repo.insert()

    assert {"is invalid", [type: {:array, Plausible.Billing.Ecto.Feature}, validation: :cast]} ==
             changeset.errors[:features]
  end

  test "changeset/2 loads and dumps limits" do
    team = new_user(trial_expiry_date: Date.utc_today()) |> team_of()
    plan = build(:enterprise_plan, team_id: team.id)
    attrs = %{team_member_limit: :unlimited, monthly_pageview_limit: 10_000}

    assert {:ok, enterprise_plan} =
             plan
             |> EnterprisePlan.changeset(attrs)
             |> Plausible.Repo.insert()

    assert %EnterprisePlan{team_member_limit: :unlimited, monthly_pageview_limit: 10_000} =
             enterprise_plan

    assert %EnterprisePlan{team_member_limit: :unlimited, monthly_pageview_limit: 10_000} =
             Plausible.Repo.get(EnterprisePlan, enterprise_plan.id)
  end
end
