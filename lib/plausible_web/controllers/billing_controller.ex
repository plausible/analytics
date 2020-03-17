defmodule PlausibleWeb.BillingController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Billing
  require Logger

  plug PlausibleWeb.RequireAccountPlug

  def change_plan_form(conn, _params) do
    subscription = Billing.active_subscription_for(conn.assigns[:current_user].id)
    if subscription do
      render(conn, "change_plan.html", subscription: subscription, layout: {PlausibleWeb.LayoutView, "focus.html"})
    else
      redirect(conn, to: "/billing/upgrade")
    end
  end

  def change_plan(conn, %{"plan_name" => plan}) when plan in ["personal", "startup", "business"] do
    new_plan = String.to_existing_atom(plan)

    case Billing.change_plan(conn.assigns[:current_user], new_plan) do
      {:ok, _subscription} ->
        conn
        |> put_flash(:success, "Plan changed successfully")
        |> redirect(to: "/settings")
      {:error, e} ->
        Sentry.capture_message("Error changing plans", extra: %{errors: inspect(e), new_plan: new_plan, user_id: conn.assigns[:current_user].id})
        conn
        |> put_flash(:error, "Something went wrong. Please try again or contact support at uku@plausible.io")
        |> redirect(to: "/settings")
    end
  end

  def upgrade(conn, _params) do
    usage = Plausible.Billing.usage(conn.assigns[:current_user])
    today = Timex.today()

    render(conn, "upgrade.html", usage: usage, today: today, user: conn.assigns[:current_user], layout: {PlausibleWeb.LayoutView, "focus.html"})
  end

  def success(conn, _params) do
    conn
    |> put_flash(:success, "Subscription created successfully")
    |> redirect(to: "/")
  end
end
