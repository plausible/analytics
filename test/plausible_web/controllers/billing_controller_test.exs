defmodule PlausibleWeb.BillingControllerTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /change-plan" do
    setup [:create_user, :log_in]

    test "redirects to /upgrade if user does not have a subscription", %{conn: conn} do
      conn = get(conn, "/billing/change-plan")

      assert redirected_to(conn) == "/billing/upgrade"
    end
  end

  describe "POST /change-plan" do
    setup [:create_user, :log_in]

    test "calls Paddle API to update subscription" do

    end
  end
end
