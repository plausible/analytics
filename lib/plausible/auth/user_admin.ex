defmodule Plausible.Auth.UserAdmin do
  use Plausible.Repo

  def custom_index_query(_conn, _schema, query) do
    subscripton_q = from(s in Plausible.Billing.Subscription, order_by: [desc: s.inserted_at])
    from(r in query, preload: [subscription: ^subscripton_q])
  end

  def form_fields(_) do
    [
      name: nil,
      email: nil,
      trial_expiry_date: nil
    ]
  end

  def index(_) do
    [
      name: nil,
      email: nil,
      trial_expiry_date: nil,
      subscription_tier: %{value: &subscription_tier/1},
      subscription_status: %{value: &subscription_status/1}
    ]
  end

  defp subscription_tier(user) do
    if user.subscription && user.subscription.status == "active" do
      quota = PlausibleWeb.AuthView.subscription_quota(user.subscription)
      interval = PlausibleWeb.AuthView.subscription_interval(user.subscription)
      "#{quota} (#{interval})"
    else
      "--"
    end
  end

  defp subscription_status(user) do
    cond do
      user.subscription ->
        PlausibleWeb.AuthView.present_subscription_status(user.subscription.status)

      Plausible.Billing.on_trial?(user) ->
        "On trial"

      true ->
        "Trial expired"
    end
  end
end
