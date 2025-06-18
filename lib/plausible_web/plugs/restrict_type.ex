defmodule Plausible.Plugs.RestrictType do
  @moduledoc """
  Plug for restricting user access by type.
  """

  import Plug.Conn

  alias PlausibleWeb.Router.Helpers, as: Routes

  def init(type), do: type

  def call(conn, type) do
    user = conn.assigns[:current_user]

    if user && Plausible.Users.type(user) == type do
      conn
      |> Phoenix.Controller.redirect(to: Routes.site_path(conn, :index))
      |> halt()
    else
      conn
    end
  end
end
