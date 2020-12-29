defmodule PlausibleWeb.UpgradeBillingPlug do
  import Phoenix.Controller
  import Plug.Conn
  use Plausible.Repo

  def init(options) do
    options
  end

  def call(conn, _opts) do
    user = conn.assigns[:current_user]

    if user && Plausible.Billing.needs_to_upgrade?(conn.assigns[:current_user]) do
      conn
      |> redirect(to: "/settings")
      |> halt
    else
      conn
    end
  end
end
