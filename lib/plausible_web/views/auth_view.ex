defmodule PlausibleWeb.AuthView do
  use PlausibleWeb, :view
  alias Plausible.Billing.Plans

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
    Plans.allowance(subscription) |> PlausibleWeb.StatsView.large_number_format()
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
