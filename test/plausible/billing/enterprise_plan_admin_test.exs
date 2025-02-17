defmodule Plausible.Billing.EnterprisePlanAdminTest do
  use Plausible.DataCase, async: true
  use Plausible.Teams.Test

  alias Plausible.Billing.EnterprisePlan
  alias Plausible.Billing.EnterprisePlanAdmin

  @moduletag :ee_only

  test "sanitizes number inputs and whitespace" do
    user = new_user()
    _site = new_site(owner: user)
    team = team_of(user)

    changeset =
      EnterprisePlanAdmin.create_changeset(%EnterprisePlan{}, %{
        "team_id" => to_string(team.id),
        "paddle_plan_id" => " . 123456 ",
        "billing_interval" => "monthly",
        "monthly_pageview_limit" => "100,000,000",
        "site_limit" => " 10 ",
        "team_member_limit" => "-1 ",
        "hourly_api_request_limit" => "  1,000",
        "features" => ["goals"]
      })

    assert changeset.valid?
    assert changeset.changes.team_id == team_of(user).id
    assert changeset.changes.paddle_plan_id == "123456"
    assert changeset.changes.billing_interval == :monthly
    assert changeset.changes.monthly_pageview_limit == 100_000_000
    assert changeset.changes.site_limit == 10
    assert changeset.changes.hourly_api_request_limit == 1000
    assert changeset.changes.features == [Plausible.Billing.Feature.Goals]
  end

  test "scrubs empty attrs" do
    user = new_user()
    _site = new_site(owner: user)
    team = team_of(user)

    changeset =
      EnterprisePlanAdmin.create_changeset(%EnterprisePlan{}, %{
        "team_id" => to_string(team.id),
        "paddle_plan_id" => " ,.     ",
        "billing_interval" => "monthly",
        "monthly_pageview_limit" => "100,000,000",
        "site_limit" => " 10 ",
        "team_member_limit" => "-1 ",
        "hourly_api_request_limit" => "  1,000",
        "features" => ["goals"]
      })

    refute changeset.valid?
    assert {_, validation: :required} = changeset.errors[:paddle_plan_id]
  end
end
