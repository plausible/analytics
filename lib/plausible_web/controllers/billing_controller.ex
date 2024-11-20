defmodule PlausibleWeb.BillingController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  require Logger
  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing
  alias Plausible.Billing.{Plans, Subscription}

  plug PlausibleWeb.RequireAccountPlug

  def ping_subscription(%Plug.Conn{} = conn, _params) do
    subscribed? =
      Plausible.Teams.Adapter.Read.Billing.has_active_subscription?(conn.assigns.current_user)

    json(conn, %{is_subscribed: subscribed?})
  end

  def choose_plan(conn, _params) do
    current_user = conn.assigns.current_user

    if Plausible.Teams.Adapter.Read.Billing.enterprise_configured?(current_user) do
      redirect(conn, to: Routes.billing_path(conn, :upgrade_to_enterprise_plan))
    else
      render(conn, "choose_plan.html",
        skip_plausible_tracking: true,
        connect_live_socket: true
      )
    end
  end

  def upgrade_to_enterprise_plan(conn, _params) do
    current_user = conn.assigns.current_user
    subscription = Plausible.Teams.Adapter.Read.Billing.get_subscription(current_user)

    {latest_enterprise_plan, price} =
      Plans.latest_enterprise_plan_with_price(current_user, PlausibleWeb.RemoteIP.get(conn))

    subscription_resumable? =
      Plausible.Billing.Subscriptions.resumable?(subscription)

    subscribed_to_latest? =
      subscription_resumable? &&
        subscription.paddle_plan_id == latest_enterprise_plan.paddle_plan_id

    cond do
      Subscription.Status.in?(subscription, [
        Subscription.Status.past_due(),
        Subscription.Status.paused()
      ]) ->
        redirect(conn, to: Routes.settings_path(conn, :subscription))

      subscribed_to_latest? ->
        render(conn, "change_enterprise_plan_contact_us.html", skip_plausible_tracking: true)

      true ->
        render(conn, "upgrade_to_enterprise_plan.html",
          latest_enterprise_plan: latest_enterprise_plan,
          price: price,
          subscription_resumable: subscription_resumable?,
          contact_link: "https://plausible.io/contact",
          skip_plausible_tracking: true
        )
    end
  end

  def upgrade_success(conn, _params) do
    render(conn, "upgrade_success.html")
  end

  def change_plan_preview(conn, %{"plan_id" => new_plan_id}) do
    current_user = conn.assigns.current_user

    case preview_subscription(current_user, new_plan_id) do
      {:ok, {subscription, preview_info}} ->
        render(conn, "change_plan_preview.html",
          back_link: Routes.billing_path(conn, :choose_plan),
          skip_plausible_tracking: true,
          subscription: subscription,
          preview_info: preview_info
        )

      _ ->
        msg =
          "Something went wrong with loading your plan change information. Please try again, or contact us at support@plausible.io if the issue persists."

        Sentry.capture_message("Error loading change plan preview",
          extra: %{
            message: msg,
            new_plan_id: new_plan_id,
            user_id: current_user.id
          }
        )

        conn
        |> put_flash(:error, msg)
        |> redirect(to: Routes.billing_path(conn, :choose_plan))
    end
  end

  def change_plan(conn, %{"new_plan_id" => new_plan_id}) do
    current_user = conn.assigns.current_user

    case Billing.change_plan(current_user, new_plan_id) do
      {:ok, _subscription} ->
        conn
        |> put_flash(:success, "Plan changed successfully")
        |> redirect(to: Routes.settings_path(conn, :subscription))

      {:error, e} ->
        msg =
          case e do
            {:over_plan_limits, exceeded_limits} ->
              "Unable to subscribe to this plan because the following limits are exceeded: #{PlausibleWeb.TextHelpers.pretty_list(exceeded_limits)}"

            %{"code" => 147} ->
              # https://developer.paddle.com/api-reference/intro/api-error-codes
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
            user_id: current_user.id
          }
        )

        conn
        |> put_flash(:error, msg)
        |> redirect(to: Routes.settings_path(conn, :subscription))
    end
  end

  defp preview_subscription(user, new_plan_id) do
    subscription = Billing.active_subscription_for(user)

    if subscription do
      with {:ok, preview_info} <- Billing.change_plan_preview(subscription, new_plan_id) do
        {:ok, {subscription, preview_info}}
      end
    else
      {:error, :no_subscription}
    end
  end
end
