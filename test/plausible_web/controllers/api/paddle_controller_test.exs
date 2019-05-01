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
        "status" => "active"
      })

      assert json_response(conn, 200) == ""
      subscription = Repo.get_by(Plausible.Billing.Subscription, user_id: user.id)
      assert subscription.paddle_subscription_id == @subscription_id
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
        "status" => "active"
      })

      assert json_response(conn, 200) == ""
      subscription = Repo.get_by(Plausible.Billing.Subscription, user_id: user.id)
      assert subscription.paddle_plan_id == "new-plan-id"
    end
  end
end
