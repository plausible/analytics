defmodule Plausible.Billing.PlansTest do
  use Plausible.DataCase
  use Bamboo.Test, shared: true
  alias Plausible.Billing.Plans

  test "suggested plan name" do
    assert Plans.suggested_plan_name(110_000) == "200k/mo"
  end

  test "suggested plan cost" do
    assert Plans.suggested_plan_cost(110_000) == "$18/mo"
  end
end
