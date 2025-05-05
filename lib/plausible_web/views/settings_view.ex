defmodule PlausibleWeb.SettingsView do
  use PlausibleWeb, :view
  use Phoenix.Component, global_prefixes: ~w(x-)
  use Plausible

  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing.{Plans, Subscription}

  def subscription_interval(subscription) do
    Plans.subscription_interval(subscription)
  end

  def format_invoices(invoice_list) do
    Enum.map(invoice_list, fn invoice ->
      %{
        date: invoice["payout_date"] |> Date.from_iso8601!() |> Calendar.strftime("%b %-d, %Y"),
        amount: (invoice["amount"] / 1) |> :erlang.float_to_binary(decimals: 2),
        currency: invoice["currency"] |> PlausibleWeb.BillingView.present_currency(),
        url: invoice["receipt_url"]
      }
    end)
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
