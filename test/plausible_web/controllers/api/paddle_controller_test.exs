defmodule PlausibleWeb.Api.PaddleControllerTest do
  use PlausibleWeb.ConnCase
  use Plausible.Repo
  import Plausible.TestUtils

  @subscription_id "subscription-123"
  @plan_id "plan-123"

  describe "subscription_created" do
    setup [:create_user]

    test "creates a subscription", %{conn: conn, user: user} do
      conn = post(conn, "/api/paddle/webhook", %{
        "alert_name" => "subscription_created",
        "subscription_id" => @subscription_id,
        "subscription_plan_id" => @plan_id,
        "update_url" => "update_url.com",
        "cancel_url" => "cancel_url.com",
        "passthrough" => user.id,
        "status" => "active",
        "next_bill_date" => "2019-06-01",
        "unit_price" => "6.00"
      })

      assert json_response(conn, 200) == ""
      subscription = Repo.get_by(Plausible.Billing.Subscription, user_id: user.id)
      assert subscription.paddle_subscription_id == @subscription_id
      assert subscription.next_bill_date == ~D[2019-06-01]
      assert subscription.next_bill_amount == "6.00"
    end
  end

  describe "subscription_updated" do
    setup [:create_user]

    test "updates an existing subscription", %{conn: conn, user: user} do
      subscription = insert(:subscription, user: user)

      conn = post(conn, "/api/paddle/webhook", %{
        "alert_name" => "subscription_updated",
        "subscription_id" => subscription.paddle_subscription_id,
        "subscription_plan_id" => "new-plan-id",
        "update_url" => "update_url.com",
        "cancel_url" => "cancel_url.com",
        "passthrough" => user.id,
        "status" => "active",
        "next_bill_date" => "2019-06-01",
        "new_unit_price" => "12.00"
      })

      assert json_response(conn, 200) == ""
      subscription = Repo.get_by(Plausible.Billing.Subscription, user_id: user.id)
      assert subscription.paddle_plan_id == "new-plan-id"
      assert subscription.next_bill_amount == "12.00"
    end
  end

  describe "subscription_cancelled" do
    setup [:create_user]

    test "sets the status to deleted", %{conn: conn, user: user} do
      subscription = insert(:subscription, status: "active", user: user)

      conn = post(conn, "/api/paddle/webhook", %{
        "alert_name" => "subscription_cancelled",
        "subscription_id" => subscription.paddle_subscription_id,
        "status" => "deleted"
      })

      assert json_response(conn, 200) == ""
      subscription = Repo.get_by(Plausible.Billing.Subscription, user_id: user.id)
      assert subscription.status == "deleted"
    end
  end
end
