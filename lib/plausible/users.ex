defmodule Plausible.Users do
  @moduledoc """
  User context
  """

  import Ecto.Query

  alias Plausible.Auth.User
  alias Plausible.Billing.Subscription
  alias Plausible.Repo

  def with_subscription(%User{id: user_id} = user) do
    Repo.preload(user, subscription: last_subscription_query(user_id))
  end

  def with_subscription(user_id) when is_integer(user_id) do
    Repo.one(
      from(user in User,
        left_join: last_subscription in subquery(last_subscription_query(user_id)),
        on: last_subscription.user_id == user.id,
        left_join: subscription in Subscription,
        on: subscription.id == last_subscription.id,
        where: user.id == ^user_id,
        preload: [subscription: subscription]
      )
    )
  end

  defp last_subscription_query(user_id) do
    from(subscription in Plausible.Billing.Subscription,
      where: subscription.user_id == ^user_id,
      order_by: [desc: subscription.inserted_at],
      limit: 1
    )
  end
end
