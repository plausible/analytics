defmodule PlausibleWeb.AuthView do
  use PlausibleWeb, :view

  @monthly_plans [
    "558018",
    "558745",
    "597485",
    "597487",
    "597642",
    "558746",
    "597309",
    "597311",
    "642355",
    "642352"
  ]
  @yearly_plans [
    "572810",
    "590752",
    "597486",
    "597488",
    "597643",
    "590753",
    "597310",
    "597312",
    "642356",
    "642354"
  ]

  @subscription_quotas %{
    "558018" => "10k",
    "558745" => "100k",
    "597485" => "200k",
    "597487" => "500k",
    "597642" => "1m",
    "558746" => "1m",
    "597309" => "2m",
    "597311" => "5m",
    "572810" => "10k",
    "590752" => "100k",
    "597486" => "200k",
    "597488" => "500k",
    "597643" => "1m",
    "590753" => "1m",
    "597310" => "2m",
    "597312" => "5m",
    "642354" => "10m",
    "642352" => "10m",
    "642355" => "20m",
    "642356" => "20m",
    "free_10k" => "10k"
  }

  def admin_email do
    Application.get_env(:plausible, :admin_email)
  end

  def base_domain do
    PlausibleWeb.Endpoint.host()
  end

  def plausible_url do
    PlausibleWeb.Endpoint.url()
  end

  def subscription_quota(subscription) do
    @subscription_quotas[subscription.paddle_plan_id]
  end

  def subscription_interval(subscription) do
    cond do
      subscription.paddle_plan_id in @monthly_plans -> "monthly"
      subscription.paddle_plan_id in @yearly_plans -> "yearly"
      subscription.paddle_plan_id == "free_10k" -> "N/A"
      true -> raise "Unknown interval for subscription #{subscription.paddle_plan_id}"
    end
  end

  def delimit_integer(number) do
    Integer.to_charlist(number)
    |> :lists.reverse()
    |> delimit_integer([])
    |> String.Chars.to_string()
  end

  defp delimit_integer([a, b, c, d | tail], acc) do
    delimit_integer([d | tail], [",", c, b, a | acc])
  end

  defp delimit_integer(list, acc) do
    :lists.reverse(list) ++ acc
  end

  def present_subscription_status("active"), do: "Active"
  def present_subscription_status("past_due"), do: "Past due"
  def present_subscription_status("deleted"), do: "Cancelled"
  def present_subscription_status("paused"), do: "Paused"
  def present_subscription_status(status), do: status

  def subscription_colors("active"), do: "bg-green-100 text-green-800"
  def subscription_colors("past_due"), do: "bg-yellow-100 text-yellow-800"
  def subscription_colors("paused"), do: "bg-red-100 text-red-800"
  def subscription_colors("deleted"), do: "bg-red-100 text-red-800"
  def subscription_colors(_), do: ""
end
