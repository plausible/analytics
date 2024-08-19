defmodule PlausibleWeb.AuthPlug do
  import Plug.Conn
  use Plausible.Repo

  alias PlausibleWeb.UserAuth

  def init(options) do
    options
  end

  def call(conn, _opts) do
    case UserAuth.get_user(conn) do
      {:ok, user} ->
        user = Plausible.Users.with_subscription(user)
        Plausible.OpenTelemetry.add_user_attributes(user)
        Sentry.Context.set_user_context(%{id: user.id, name: user.name, email: user.email})
        assign(conn, :current_user, user)

      _ ->
        conn
    end
  end
end
