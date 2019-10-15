defmodule Plausible.Billing do
  use Plausible.Repo
  alias Plausible.Billing.{Subscription, Plans, PaddleApi}
  @paddle_api Application.fetch_env!(:plausible, :paddle_api)

  def active_subscription_for(user_id) do
    Repo.get_by(Subscription, user_id: user_id, status: "active")
  end

  def subscription_created(params) do
    params = if params["passthrough"] do
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

  def change_plan(user, new_plan) do
    subscription = active_subscription_for(user.id)

    res = PaddleApi.update_subscription(subscription.paddle_subscription_id, %{
      plan_id: Plans.paddle_id_for_plan(new_plan)
    })

    case res do
      {:ok, response} ->
        Subscription.changeset(subscription, %{
          paddle_plan_id: Integer.to_string(response["plan_id"])
        }) |> Repo.update
      e -> e
    end
  end

  def needs_to_upgrade?(user) do
    if Timex.before?(trial_end_date(user), Timex.today()) do
      !active_subscription_for(user.id)
    else
      false
    end
  end

  def coupon_for(user) do
    if was_beta_user(user) do
      "8FE5AF26"
    end
  end

  def was_beta_user(user) do
    Timex.before?(user.inserted_at, ~D[2019-04-25])
  end

  def trial_days_left(user) do
    if Timex.before?(user.inserted_at, ~D[2019-04-24]) do
      Timex.diff(~D[2019-05-25], Timex.today, :days) + 1
    else
      30 - Timex.diff(Timex.today, user.inserted_at, :days)
    end
  end

  def trial_end_date(user) do
    if Timex.before?(user.inserted_at, ~D[2019-04-25]) do
      ~D[2019-05-25]
    else
      Timex.shift(user.inserted_at, days: 30) |> NaiveDateTime.to_date
    end
  end

  def usage(user) do
    user = Repo.preload(user, :sites)
    Enum.reduce(user.sites, 0, fn site, total ->
      total + site_usage(site)
    end)
  end

  defp site_usage(site) do
    Repo.aggregate(from(
      p in Plausible.Pageview,
      where: p.hostname == ^site.domain,
      where: p.inserted_at >= fragment("now() - '30 days'::interval")
    ), :count, :id
    )
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
end
