defmodule PlausibleWeb.AuthView do
  use PlausibleWeb, :view

  @subscription_names %{
    "558018" => "Personal",
    "572810" => "Personal (A)",
    "558745" => "Startup",
    "558746" => "Business",
    "558156" => "Personal (T)",
    "558199" => "Startup (T)",
    "558200" => "Business (T)"
  }

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
