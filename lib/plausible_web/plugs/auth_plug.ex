defmodule PlausibleWeb.AuthPlug do
  import Plug.Conn
  use Plausible.Repo

  def init(options) do
    options
  end

  def call(conn, _opts) do
    case get_session(conn, :current_user_id) do
      nil ->
        conn

      id ->
        subscription_query =
          from(s in Plausible.Billing.Subscription, order_by: [desc: s.inserted_at], limit: 1)

        {user, subscription} =
          Repo.one(
            from u in Plausible.Auth.User,
              left_join: s in subquery(subscription_query),
              on: s.user_id == u.id,
              where: u.id == ^id,
              select: {u, s}
          )

        user = Map.put(user, :subscription, subscription)

        if user do
          Sentry.Context.set_user_context(%{id: user.id, name: user.name, email: user.email})
          assign(conn, :current_user, user)
        else
          conn
        end
    end
  end
end
