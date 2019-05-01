defmodule Plausible.Billing do
  use Plausible.Repo
  alias Plausible.Billing.Subscription

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

  defp format_subscription(params) do
    %{
      paddle_subscription_id: params["subscription_id"],
      paddle_plan_id: params["subscription_plan_id"],
      cancel_url: params["cancel_url"],
      update_url: params["update_url"],
      user_id: params["passthrough"],
      status: params["status"]
    }
  end
end
