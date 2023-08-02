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

  def delete(_conn, %{data: user}) do
    Plausible.Auth.delete_user(user)
  end

  def index(_) do
    [
      name: nil,
      email: nil,
      inserted_at: %{name: "Created at", value: &format_date(&1.inserted_at)},
      trial_expiry_date: %{name: "Trial expiry", value: &format_date(&1.trial_expiry_date)},
      subscription_plan: %{value: &subscription_plan/1},
      subscription_status: %{value: &subscription_status/1},
      grace_period: %{value: &grace_period_status/1}
    ]
  end

  def resource_actions(_) do
    [
      unlock: %{
        name: "Unlock",
        action: fn _, user -> unlock(user) end
      },
      lock: %{
        name: "Lock",
        action: fn _, user -> lock(user) end
      }
    ]
  end

  defp lock(user) do
    if user.grace_period do
      Plausible.Billing.SiteLocker.set_lock_status_for(user, true)
      user |> Plausible.Auth.GracePeriod.end_changeset() |> Repo.update()
    else
      {:error, user, "No active grace period on this user"}
    end
  end

  defp unlock(user) do
    if user.grace_period do
      Plausible.Auth.GracePeriod.remove_changeset(user) |> Repo.update()
      Plausible.Billing.SiteLocker.set_lock_status_for(user, false)
      {:ok, user}
    else
      {:error, user, "No active grace period on this user"}
    end
  end

  defp grace_period_status(%{grace_period: grace_period}) do
    case grace_period do
      nil ->
        "--"

      %{manual_lock: true, is_over: true} ->
        "Manually locked"

      %{manual_lock: true, is_over: false} ->
        "Waiting for manual lock"

      %{is_over: true} ->
        "ended"

      %{end_date: %Date{} = end_date} ->
        days_left = Timex.diff(end_date, Timex.now(), :days)
        "#{days_left} days left"
    end
  end

  defp subscription_plan(user) do
    if user.subscription && user.subscription.status == "active" &&
         user.subscription.paddle_subscription_id do
      quota = PlausibleWeb.AuthView.subscription_quota(user.subscription)
      interval = PlausibleWeb.AuthView.subscription_interval(user.subscription)

      manage_url =
        Plausible.Billing.PaddleApi.vendors_domain() <>
          "/subscriptions/customers/manage/" <>
          user.subscription.paddle_subscription_id

      {:safe, ~s(<a href="#{manage_url}">#{quota} \(#{interval}\)</a>)}
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

  defp format_date(nil), do: "--"

  defp format_date(date) do
    Timex.format!(date, "{Mshort} {D}, {YYYY}")
  end
end
