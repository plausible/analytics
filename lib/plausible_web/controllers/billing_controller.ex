defmodule PlausibleWeb.BillingController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Billing
  require Logger

  plug PlausibleWeb.RequireAccountPlug

  def upgrade(conn, _params) do
    user =
      conn.assigns[:current_user]
      |> Repo.preload(:enterprise_plan)

    cond do
      user.subscription && user.subscription.status == "active" ->
        redirect(conn, to: Routes.billing_path(conn, :change_plan_form))

      user.enterprise_plan ->
        redirect(conn,
          to: Routes.billing_path(conn, :upgrade_enterprise_plan, user.enterprise_plan.id)
        )

      true ->
        render(conn, "upgrade.html",
          usage: Plausible.Billing.usage(user),
          user: user,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )
    end
  end

  def upgrade_enterprise_plan(conn, %{"plan_id" => plan_id}) do
    user =
      conn.assigns[:current_user]
      |> Repo.preload(:enterprise_plan)

    if user.enterprise_plan && user.enterprise_plan.id == String.to_integer(plan_id) do
      usage = Plausible.Billing.usage(conn.assigns[:current_user])

      render(conn, "upgrade_to_plan.html",
        usage: usage,
        user: user,
        layout: {PlausibleWeb.LayoutView, "focus.html"}
      )
    else
      render_error(conn, 404)
    end
  end

  def upgrade_to_plan(conn, %{"plan_id" => plan_id}) do
    plan = Plausible.Billing.Plans.for_product_id(plan_id)

    if plan do
      cycle = if plan[:monthly_product_id] == plan_id, do: "monthly", else: "yearly"
      plan = Map.merge(plan, %{cycle: cycle, product_id: plan_id})
      usage = Plausible.Billing.usage(conn.assigns[:current_user])

      render(conn, "upgrade_to_plan.html",
        usage: usage,
        plan: plan,
        user: conn.assigns[:current_user],
        layout: {PlausibleWeb.LayoutView, "focus.html"}
      )
    else
      render_error(conn, 404)
    end
  end

  def upgrade_success(conn, _params) do
    render(conn, "upgrade_success.html", layout: {PlausibleWeb.LayoutView, "focus.html"})
  end

  def change_plan_form(conn, _params) do
    user =
      conn.assigns[:current_user]
      |> Repo.preload(:enterprise_plan)

    subscription = Billing.active_subscription_for(user.id)

    cond do
      subscription && user.enterprise_plan ->
        redirect(conn,
          to: Routes.billing_path(conn, :change_enterprise_plan, user.enterprise_plan.id)
        )

      subscription ->
        render(conn, "change_plan.html",
          subscription: subscription,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )

      true ->
        redirect(conn, to: Routes.billing_path(conn, :upgrade))
    end
  end

  def change_enterprise_plan(conn, %{"plan_id" => plan_id}) do
    user =
      conn.assigns[:current_user]
      |> Repo.preload(:enterprise_plan)

    cond do
      is_nil(user.subscription) ->
        redirect(conn, to: "/billing/upgrade")

      is_nil(user.enterprise_plan) ->
        render_error(conn, 404)

      user.enterprise_plan.id !== String.to_integer(plan_id) ->
        render_error(conn, 404)

      user.enterprise_plan.paddle_plan_id == user.subscription.paddle_plan_id ->
        render(conn, "change_enterprise_plan_contact_us.html",
          user: user,
          plan: user.enterprise_plan,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )

      true ->
        render(conn, "change_enterprise_plan.html",
          user: user,
          plan: user.enterprise_plan,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )
    end
  end

  def change_plan_preview(conn, %{"plan_id" => new_plan_id}) do
    subscription = Billing.active_subscription_for(conn.assigns[:current_user].id)

    if subscription do
      {:ok, preview_info} = Billing.change_plan_preview(subscription, new_plan_id)

      render(conn, "change_plan_preview.html",
        subscription: subscription,
        preview_info: preview_info,
        layout: {PlausibleWeb.LayoutView, "focus.html"}
      )
    else
      redirect(conn, to: "/billing/upgrade")
    end
  end

  def change_plan(conn, %{"new_plan_id" => new_plan_id}) do
    case Billing.change_plan(conn.assigns[:current_user], new_plan_id) do
      {:ok, _subscription} ->
        conn
        |> put_flash(:success, "Plan changed successfully")
        |> redirect(to: "/settings")

      {:error, e} ->
        # https://developer.paddle.com/api-reference/intro/api-error-codes
        msg =
          case e do
            %{"code" => 147} ->
              "We were unable to charge your card. Click 'update billing info' to update your payment details and try again."

            %{"message" => msg} when not is_nil(msg) ->
              msg

            _ ->
              "Something went wrong. Please try again or contact support at support@plausible.io"
          end

        Sentry.capture_message("Error changing plans",
          extra: %{
            errors: inspect(e),
            message: msg,
            new_plan_id: new_plan_id,
            user_id: conn.assigns[:current_user].id
          }
        )

        conn
        |> put_flash(:error, msg)
        |> redirect(to: "/settings")
    end
  end
end
