defmodule Plausible.Billing do
  use Plausible.Repo
  alias Plausible.Billing.{Subscription, Plans, PaddleApi}

  def active_subscription_for(user_id) do
    Repo.get_by(Subscription, user_id: user_id, status: "active")
  end

  def subscription_created(params) do
    changeset = Subscription.changeset(%Subscription{}, format_subscription(params))

    Repo.insert(changeset)
  end

  def subscription_updated(params) do
    subscription = Repo.get_by!(Subscription, paddle_subscription_id: params["subscription_id"])
    changeset = Subscription.changeset(subscription, format_subscription(params))

    Repo.update(changeset)
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

  def trial_days_left(user) do
    if Timex.before?(user.inserted_at, ~D[2019-04-24]) do
      Timex.diff(~D[2019-05-24], Timex.today, :days) + 1
    else
      30 - Timex.diff(Timex.today, user.inserted_at, :days)
    end
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
