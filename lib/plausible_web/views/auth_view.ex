defmodule PlausibleWeb.AuthView do
  use Plausible
  use PlausibleWeb, :view
  alias Plausible.Billing.Plans

  def subscription_quota(subscription, options \\ [])

  def subscription_quota(nil, _options), do: "Free trial"

  def subscription_quota(subscription, options) do
    pageview_limit = Plausible.Teams.Billing.monthly_pageview_limit(subscription)

    quota =
      if pageview_limit == :unlimited do
        "unlimited"
      else
        PlausibleWeb.StatsView.large_number_format(pageview_limit)
      end

    if Keyword.get(options, :format) == :long do
      "#{quota} pageviews"
    else
      quota
    end
  end

  def subscription_interval(subscription) do
    Plans.subscription_interval(subscription)
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
