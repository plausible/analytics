defmodule PlausibleWeb.AuthView do
  use PlausibleWeb, :view

  @subscription_names %{
    "558018" => "10k / monthly",
    "558745" => "100k / monthly",
    "558746" => "1m / monthly",
    "572810" => "10k / yearly",
    "590752" => "100k / yearly",
    "590753" => "1m / yearly",
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
end
