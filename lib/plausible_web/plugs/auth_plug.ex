defmodule PlausibleWeb.AuthPlug do
  import Plug.Conn
  use Plausible.Repo

  def init(options) do
    options
  end

  def call(conn, _opts) do
    with id when is_integer(id) <- get_session(conn, :current_user_id),
         %Plausible.Auth.User{} = user <- find_user(id) do
      Plausible.OpenTelemetry.add_user_attributes(user)
      Sentry.Context.set_user_context(%{id: user.id, name: user.name, email: user.email})
      assign(conn, :current_user, user)
    else
      nil -> conn
    end
  end

  defp find_user(user_id) do
    last_subscription_query =
      from(subscription in Plausible.Billing.Subscription,
        where: subscription.user_id == ^user_id,
        order_by: [desc: subscription.inserted_at],
        limit: 1
      )

    user_query =
      from(user in Plausible.Auth.User,
        left_join: last_subscription in subquery(last_subscription_query),
        on: last_subscription.user_id == user.id,
        left_join: subscription in Plausible.Billing.Subscription,
        on: subscription.id == last_subscription.id,
        where: user.id == ^user_id,
        preload: [subscription: subscription]
      )

    Repo.one(user_query)
  end
end
