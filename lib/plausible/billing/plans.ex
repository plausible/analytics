defmodule Plausible.Billing.Plans do
  @real_plans %{
  }

  @test_plans %{
    personal: 558156,
    startup: 558199,
    business: 558200
  }

  def paddle_id_for_plan(plan) do
    @test_plans[plan]
  end
end
