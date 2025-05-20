defmodule PlausibleWeb.DevSubscriptionController do
  use Plausible

  on_ee do
    use PlausibleWeb, :controller

    alias Plausible.Billing.DevSubscriptions

    plug PlausibleWeb.RequireAccountPlug

    plug Plausible.Plugs.AuthorizeTeamAccess, [:owner, :billing]

    def create_form(conn, %{"plan_id" => plan_id}) do
      render(conn, "create_dev_subscription.html",
        back_link: Routes.billing_path(conn, :choose_plan),
        plan_id: plan_id
      )
    end

    def update_form(conn, _params) do
      team = conn.assigns.current_team |> Plausible.Teams.with_subscription()

      if is_nil(team.subscription),
        do: raise("Can't render subscription update form without subscription")

      render(conn, "update_dev_subscription.html",
        back_link: Routes.settings_path(conn, :subscription),
        current_status: team.subscription.status
      )
    end

    def cancel_form(conn, _params) do
      team = conn.assigns.current_team |> Plausible.Teams.with_subscription()

      if is_nil(team.subscription),
        do: raise("Can't render subscription cancel form without subscription")

      render(conn, "cancel_dev_subscription.html",
        back_link: Routes.settings_path(conn, :subscription),
        enterprise_plan?: Plausible.Teams.Billing.enterprise_configured?(team)
      )
    end

    def create(conn, %{"plan_id" => plan_id}) do
      team = conn.assigns.current_team
      DevSubscriptions.create_after_1s(team.id, plan_id)
      redirect(conn, to: Routes.billing_path(PlausibleWeb.Endpoint, :upgrade_success))
    end

    def update(conn, %{"status" => status}) do
      team = conn.assigns.current_team

      :ok = DevSubscriptions.update(team.id, status)

      conn
      |> put_flash(:success, "Subscription status set to '#{status}'")
      |> redirect(to: Routes.settings_path(conn, :subscription))
    end

    def cancel(conn, %{"action" => action}) do
      team = conn.assigns.current_team

      flash_msg =
        case action do
          "cancel" ->
            DevSubscriptions.cancel(team.id)
            "Subscription cancelled"

          "cancel_and_expire" ->
            DevSubscriptions.cancel(team.id, set_expired?: true)
            "Subscription cancelled and set as 'expired'"

          "delete" ->
            DevSubscriptions.delete(team.id)
            "Subscription deleted"

          "delete_enterprise" ->
            DevSubscriptions.delete(team.id, delete_enterprise?: true)
            "Subscription and enterprise plans deleted"
        end

      conn
      |> put_flash(:success, flash_msg)
      |> redirect(to: Routes.settings_path(conn, :subscription))
    end
  end
end
