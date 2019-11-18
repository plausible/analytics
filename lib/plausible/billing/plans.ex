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

  def allowance(subscription) do
    cond do
      subscription.paddle_plan_id == "572810" -> # Personal annual
        10_000
      subscription.paddle_plan_id == "free_10k" ->
        10_000
      is?(subscription, :personal) ->
        10_000
      is?(subscription, :startup) ->
        100_000
      is?(subscription, :business) ->
        1_000_000
      true ->
        raise "Subscription not found for #{subscription.paddle_plan_id}"
    end
  end
end
