defmodule Plausible.Billing do
  use Plausible.Repo
  alias Plausible.Billing.{Subscription, PaddleApi}
  @paddle_api Application.fetch_env!(:plausible, :paddle_api)

  def active_subscription_for(user_id) do
    Repo.get_by(Subscription, user_id: user_id, status: "active")
  end

  def subscription_created(params) do
    params = if present?(params["passthrough"]) do
      params
    else
      user = Repo.get_by(Plausible.Auth.User, email: params["email"])
      Map.put(params, "passthrough", user && user.id)
    end

    changeset = Subscription.changeset(%Subscription{}, format_subscription(params))

    Repo.insert(changeset)
  end

  def subscription_updated(params) do
    subscription = Repo.get_by!(Subscription, paddle_subscription_id: params["subscription_id"])
    changeset = Subscription.changeset(subscription, format_subscription(params))

    Repo.update(changeset)
  end

  def subscription_cancelled(params) do
    subscription = Repo.get_by(Subscription, paddle_subscription_id: params["subscription_id"])

    if subscription do
      changeset = Subscription.changeset(subscription, %{
        status: params["status"]
      })

      Repo.update(changeset)
    else
      {:ok, nil}
    end
  end

  def subscription_payment_succeeded(params) do
    subscription = Repo.get_by(Subscription, paddle_subscription_id: params["subscription_id"])

    if subscription do
      {:ok, api_subscription} = @paddle_api.get_subscription(subscription.paddle_subscription_id)
      amount = :erlang.float_to_binary(api_subscription["next_payment"]["amount"] / 1, decimals: 2)

      changeset = Subscription.changeset(subscription, %{
        next_bill_amount: amount,
        next_bill_date: api_subscription["next_payment"]["date"]
      })

      Repo.update(changeset)
    else
      {:ok, nil}
    end
  end

  def change_plan(user, new_plan_id) do
    subscription = active_subscription_for(user.id)

    res = @paddle_api.update_subscription(subscription.paddle_subscription_id, %{
      plan_id: new_plan_id
    })

    case res do
      {:ok, response} ->
        amount = :erlang.float_to_binary(response["next_payment"]["amount"] / 1, decimals: 2)

        Subscription.changeset(subscription, %{
          paddle_plan_id: Integer.to_string(response["plan_id"]),
          next_bill_amount: amount,
          next_bill_date: response["next_payment"]["date"],
        }) |> Repo.update
      e -> e
    end
  end

  def change_plan_preview(subscription, new_plan_id) do
    PaddleApi.update_subscription_preview(subscription.paddle_subscription_id, new_plan_id)
  end

  def needs_to_upgrade?(user) do
    if Timex.before?(user.trial_expiry_date, Timex.today()) do
      !active_subscription_for(user.id)
    else
      false
    end
  end

  def on_trial?(user), do: trial_days_left(user) >= 0

  def trial_days_left(user) do
    Timex.diff(user.trial_expiry_date, Timex.today(), :days)
  end

  def usage(user) do
    user = Repo.preload(user, :sites)
    Enum.reduce(user.sites, 0, fn site, total ->
      total + site_usage(site)
    end)
  end

  defp site_usage(site) do
    q = Plausible.Stats.Query.from(site.timezone, %{"period" => "30d"})
    {pageviews, _} = Plausible.Stats.Clickhouse.pageviews_and_visitors(site, q)
    pageviews
  end

  defp format_subscription(params) do
    %{
      paddle_subscription_id: params["subscription_id"],
      paddle_plan_id: params["subscription_plan_id"],
      cancel_url: params["cancel_url"],
      update_url: params["update_url"],
      user_id: params["passthrough"],
      status: params["status"],
      next_bill_date: params["next_bill_date"],
      next_bill_amount: params["unit_price"] || params["new_unit_price"]
    }
  end

  defp present?(""), do: false
  defp present?(nil), do: false
  defp present?(_), do: true

end
