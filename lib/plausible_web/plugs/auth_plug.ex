defmodule PlausibleWeb.AuthPlug do
  @moduledoc """
  Plug for populating conn assigns with user data
  on the basis of authenticated session token.

  Must be kept in sync with `PlausibleWeb.Live.AuthContext`.
  """

  import Plug.Conn
  use Plausible.Repo

  alias PlausibleWeb.UserAuth

  def init(options) do
    options
  end

  def call(conn, _opts) do
    with {:ok, user_session} <- UserAuth.get_user_session(conn),
         {:ok, user} <- UserAuth.get_user(user_session) do
      Plausible.OpenTelemetry.add_user_attributes(user)
      Sentry.Context.set_user_context(%{id: user.id, name: user.name, email: user.email})

      conn
      |> assign(:current_user, user)
      |> assign(:current_user_session, user_session)
    else
      _ ->
        conn
    end
  end
end
