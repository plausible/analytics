defmodule PlausibleWeb.AuthView do
  use Plausible
  use PlausibleWeb, :view
  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing.{Plans, Subscription}

  def subscription_quota(subscription, options \\ [])

  def subscription_quota(nil, _options), do: "Free trial"

  def subscription_quota(subscription, options) do
    subscription
    |> Plausible.Billing.Quota.monthly_pageview_limit()
    |> PlausibleWeb.StatsView.large_number_format()
    |> then(fn quota ->
      if Keyword.get(options, :format) == :long,
        do: "#{quota} pageviews",
        else: quota
    end)
  end

  def subscription_interval(subscription) do
    Plans.subscription_interval(subscription)
  end

  def format_invoices(invoice_list) do
    Enum.map(invoice_list, fn invoice ->
      %{
        date:
          invoice["payout_date"] |> Date.from_iso8601!() |> Timex.format!("{Mshort} {D}, {YYYY}"),
        amount: (invoice["amount"] / 1) |> :erlang.float_to_binary(decimals: 2),
        currency: invoice["currency"] |> PlausibleWeb.BillingView.present_currency(),
        url: invoice["receipt_url"]
      }
    end)
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

  @spec present_subscription_status(Subscription.Status.status()) :: String.t()
  def present_subscription_status(Subscription.Status.active()), do: "Active"
  def present_subscription_status(Subscription.Status.past_due()), do: "Past due"
  def present_subscription_status(Subscription.Status.deleted()), do: "Cancelled"
  def present_subscription_status(Subscription.Status.paused()), do: "Paused"
  def present_subscription_status(status), do: status

  @spec subscription_colors(Subscription.Status.status()) :: String.t()
  def subscription_colors(Subscription.Status.active()), do: "bg-green-100 text-green-800"
  def subscription_colors(Subscription.Status.past_due()), do: "bg-yellow-100 text-yellow-800"
  def subscription_colors(Subscription.Status.paused()), do: "bg-red-100 text-red-800"
  def subscription_colors(Subscription.Status.deleted()), do: "bg-red-100 text-red-800"
  def subscription_colors(_), do: ""
end
