defmodule PlausibleWeb.BillingControllerTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /change-plan" do
    setup [:create_user, :log_in]

    test "shows change plan page if user has subsription", %{conn: conn, user: user} do
      insert(:subscription, user: user)
      conn = get(conn, "/billing/change-plan")

      assert html_response(conn, 200) =~ "Change subscription plan"
    end

    test "redirects to /upgrade if user does not have a subscription", %{conn: conn} do
      conn = get(conn, "/billing/change-plan")

      assert redirected_to(conn) == "/billing/upgrade"
    end
  end

  describe "POST /change-plan" do
    setup [:create_user, :log_in]

    test "calls Paddle API to update subscription", %{conn: conn, user: user} do
      insert(:subscription, user: user)

      post(conn, "/billing/change-plan/123123")

      subscription = Plausible.Repo.get_by(Plausible.Billing.Subscription, user_id: user.id)
      assert subscription.paddle_plan_id == "123123"
      assert subscription.next_bill_date == ~D[2019-07-10]
      assert subscription.next_bill_amount == "6.00"
    end
  end

  describe "GET /billing/upgrade-success" do
    setup [:create_user, :log_in]

    test "shows success page after user subscribes", %{conn: conn} do
      conn = get(conn, "/billing/upgrade-success")

      assert html_response(conn, 200) =~ "Subscription created successfully"
    end
  end
end
