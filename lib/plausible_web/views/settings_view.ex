defmodule PlausibleWeb.SettingsView do
  use PlausibleWeb, :view
  use Phoenix.Component, global_prefixes: ~w(x-)
  use Plausible

  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing.{Plans, Subscription, Subscriptions}

  def present_plan_name(%Plausible.Billing.Plan{kind: kind}),
    do: kind |> to_string() |> String.capitalize()

  def present_plan_name(%Plausible.Billing.EnterprisePlan{}), do: "Enterprise"
  def present_plan_name(:free_10k), do: "Free"
  def present_plan_name(_), do: "Plan"

  def subscription_interval(subscription) do
    Plans.subscription_interval(subscription)
  end

  def present_subscription_interval(subscription) do
    case subscription_interval(subscription) do
      "monthly" -> "month"
      "yearly" -> "year"
      interval -> interval
    end
  end

  @spec present_subscription_status(Subscription.Status.status()) :: String.t()
  def present_subscription_status(Subscription.Status.active()), do: "Active"
  def present_subscription_status(Subscription.Status.past_due()), do: "Past due"
  def present_subscription_status(Subscription.Status.deleted()), do: "Cancelled"
  def present_subscription_status(Subscription.Status.paused()), do: "Paused"
  def present_subscription_status(status), do: status

  def subscription_pill_color(Subscription.Status.active()), do: :green
  def subscription_pill_color(Subscription.Status.past_due()), do: :yellow
  def subscription_pill_color(Subscription.Status.paused()), do: :red
  def subscription_pill_color(Subscription.Status.deleted()), do: :red
  def subscription_pill_color(_), do: :gray

  def trial_button_label(team) do
    if Plausible.Teams.Billing.enterprise_configured?(team) do
      "Upgrade"
    else
      "Choose a plan →"
    end
  end

  def change_plan_button_label(nil), do: "Upgrade"

  def change_plan_button_label(subscription) do
    if Subscriptions.resumable?(subscription) && subscription.cancel_url do
      "Change plan"
    else
      "Upgrade"
    end
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
end
