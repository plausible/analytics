defmodule Plausible.Billing.Plans do
  @plans %{
    monthly: %{
      "10k": %{product_id: "558018", due_now: "$6"},
      "100k": %{product_id: "558745", due_now: "$12"},
      "200k": %{product_id: "597485", due_now: "$18"},
      "500k": %{product_id: "597487", due_now: "$27"},
      "1m": %{product_id: "597642", due_now: "$48"},
      "2m": %{product_id: "597309", due_now: "$69"},
      "5m": %{product_id: "597311", due_now: "$99"}
    },
    yearly: %{
      "10k": %{product_id: "572810", due_now: "$48"},
      "100k": %{product_id: "590752", due_now: "$96"},
      "200k": %{product_id: "597486", due_now: "$144"},
      "500k": %{product_id: "597488", due_now: "$216"},
      "1m": %{product_id: "597643", due_now: "$384"},
      "2m": %{product_id: "597310", due_now: "$552"},
      "5m": %{product_id: "597312", due_now: "$792"}
    }
  }

  def plans do
    @plans
  end

  def allowance(subscription) do
    allowed_volume = %{
      "free_10k" => 10_000,
      "558018" => 10_000,
      "572810" => 10_000,
      "558745" => 100_000,
      "590752" => 100_000,
      "558746" => 1_000_000,
      "590753" => 1_000_000
    }

    allowed_volume[subscription.paddle_plan_id]
  end
end
