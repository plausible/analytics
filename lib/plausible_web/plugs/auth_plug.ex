defmodule PlausibleWeb.AuthPlug do
  import Plug.Conn
  use Plausible.Repo

  def init(options) do
    options
  end

  def call(conn, _opts) do
    with id when is_integer(id) <- get_session(conn, :current_user_id),
         %Plausible.Auth.User{} = user <- Plausible.Users.with_subscription(id) do
      Plausible.OpenTelemetry.add_user_attributes(user)
      Sentry.Context.set_user_context(%{id: user.id, name: user.name, email: user.email})
      assign(conn, :current_user, user)
    else
      nil -> conn
    end
  end
end
