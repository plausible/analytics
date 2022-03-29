defmodule PlausibleWeb.BillingControllerTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /upgrade" do
    setup [:create_user, :log_in]

    test "shows upgrade page when user does not have a subcription already", %{conn: conn} do
      conn = get(conn, "/billing/upgrade")

      assert html_response(conn, 200) =~ "Upgrade your free trial"
    end

    test "redirects user to change plan if they already have a plan", %{conn: conn, user: user} do
      insert(:subscription, user: user)
      conn = get(conn, "/billing/upgrade")

      assert redirected_to(conn) == "/billing/change-plan"
    end

    test "redirects user to enteprise plan page if they are configured with one", %{
      conn: conn,
      user: user
    } do
      plan = insert(:enterprise_plan, user: user)
      conn = get(conn, "/billing/upgrade")

      assert redirected_to(conn) == "/billing/upgrade/enterprise/#{plan.id}"
    end
  end

  describe "GET /upgrade/enterprise/:plan_id" do
    setup [:create_user, :log_in]

    test "renders enteprise plan upgrade page", %{conn: conn, user: user} do
      plan = insert(:enterprise_plan, user: user)

      conn = get(conn, "/billing/upgrade/enterprise/#{plan.id}")

      assert html_response(conn, 200) =~ "Upgrade your free trial"
      assert html_response(conn, 200) =~ "enterprise plan"
    end
  end

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

    test "prompts to contact us if user has enterprise plan and existing subscription",
         %{conn: conn, user: user} do
      insert(:subscription, user: user)
      insert(:enterprise_plan, user: user)
      conn = get(conn, "/billing/change-plan")

      assert html_response(conn, 200) =~ "please contact us"
    end
  end

  describe "GET /change-plan/enterprise/:plan_id" do
    setup [:create_user, :log_in]

    test "shows change plan page if user has subsription and enterprise plan", %{
      conn: conn,
      user: user
    } do
      insert(:subscription, user: user)

      plan =
        insert(:enterprise_plan,
          user: user,
          monthly_pageview_limit: 1000,
          hourly_api_request_limit: 500,
          site_limit: 100
        )

      conn = get(conn, "/billing/change-plan/enterprise/#{plan.id}")

      assert html_response(conn, 200) =~ "Change subscription plan"
      assert html_response(conn, 200) =~ "Up to <b>1k</b> monthly pageviews"
      assert html_response(conn, 200) =~ "Up to <b>500</b> hourly api requests"
      assert html_response(conn, 200) =~ "Up to <b>100</b> sites"
    end

    test "renders 404 is user does not have enterprise plan", %{conn: conn, user: user} do
      insert(:subscription, user: user)
      conn = get(conn, "/billing/change-plan/enterprise/123")

      assert conn.status == 404
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
