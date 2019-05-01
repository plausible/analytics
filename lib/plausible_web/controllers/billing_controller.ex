defmodule PlausibleWeb.BillingController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Billing
  require Logger

  plug PlausibleWeb.RequireAccountPlug when action in [:change_plan]

  def change_plan(conn, _params) do
    subscription = Billing.active_subscription_for(conn.assigns[:current_user].id)
    if subscription do
      render(conn, "change_plan.html", subscription: subscription, layout: {PlausibleWeb.LayoutView, "focus.html"})
    else
      redirect(conn, to: "/billing/upgrade")
    end
  end

  def upgrade(conn, _params) do
    render(conn, "upgrade.html", layout: {PlausibleWeb.LayoutView, "focus.html"})
  end

end
