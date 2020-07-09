defmodule PlausibleWeb.AuthView do
  use PlausibleWeb, :view

  @subscription_names %{
    "558018" => "10k / monthly",
    "558745" => "100k / monthly",
    "597485" => "200k / monthly",
    "597487" => "500k / monthly",
    "597642" => "1m / monthly",
    "558746" => "1m / monthly / grandfathered",
    "597309" => "2m / monthly",
    "597311" => "5m / monthly",
    "572810" => "10k / yearly",
    "590752" => "100k / yearly",
    "597486" => "200k / yearly",
    "597488" => "500k / yearly",
    "597643" => "1m / yearly",
    "590753" => "1m / yearly / grandfathered",
    "597310" => "2m / yearly",
    "597312" => "5m / yearly",
    "free_10k" => "10k / free"
  }

  def admin_email do
    Application.get_env(:plausible, :admin_email)
  end

  def base_domain do
    PlausibleWeb.Endpoint.host()
  end

  def plausible_url do
    PlausibleWeb.Endpoint.clean_url()
  end

  def subscription_name(subscription) do
    @subscription_names[subscription.paddle_plan_id]
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
