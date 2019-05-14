defmodule Plausible.Billing.Plans do
  @app_env System.get_env("APP_ENV") || "dev"

  @real_plans %{
    personal: "558018",
    startup: "558745",
    business: "558746"
  }

  @test_plans %{
    personal: "558156",
    startup: "558199",
    business: "558200"
  }

  def paddle_id_for_plan(plan) do
    if @app_env == "prod" do
      @real_plans[plan]
    else
      @test_plans[plan]
    end
  end

  def is?(subscription, plan) do
    paddle_id_for_plan(plan) == subscription.paddle_plan_id
  end
end
