defmodule Plausible.Billing.Plans do
  @app_env System.get_env("APP_ENV") || "dev"

  @plans %{
    monthly: %{
      "10k": %{product_id: "558018", due_now: "$6"},
      "100k": %{product_id: "558745", due_now: "$12"},
      "1m": %{product_id: "558746", due_now: "$36"},
    },
    yearly: %{
      "10k": %{product_id: "572810", due_now: "$48"},
      "100k": %{product_id: "590752", due_now: "$96"},
      "1m": %{product_id: "590753", due_now: "$288"}
    },
  }

  def plans do
    @plans
  end

  #def paddle_id_for_plan(plan) do
  #  @plans[plan]
  #end

  #def is?(subscription, plan) do
  #  paddle_id_for_plan(plan) == subscription.paddle_plan_id
  #end

  #def allowance(subscription) do
  #  cond do
  #    subscription.paddle_plan_id == "572810" -> # Personal annual
  #      10_000
  #    subscription.paddle_plan_id == "free_10k" ->
  #      10_000
  #    is?(subscription, :personal) ->
  #      10_000
  #    is?(subscription, :startup) ->
  #      100_000
  #    is?(subscription, :business) ->
  #      1_000_000
  #    true ->
  #      raise "Subscription not found for #{subscription.paddle_plan_id}"
  #  end
  #end
end
