defmodule Plausible.Plugs.RestrictUserType do
  @moduledoc """
  Plug for restricting user access by type.
  """

  use PlausibleWeb.VerifiedRoutes

  import Plug.Conn

  def init(opts) do
    Keyword.fetch!(opts, :deny)
  end

  def call(conn, deny_type) do
    user = conn.assigns[:current_user]

    if user && Plausible.Users.type(user) == deny_type do
      conn
      |> Phoenix.Controller.redirect(to: ~p"/sites")
      |> halt()
    else
      conn
    end
  end
end
