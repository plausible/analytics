defmodule PlausibleWeb.AdminControllerTest do
  use PlausibleWeb.ConnCase

  describe "GET /crm/auth/user/:user_id/usage" do
    setup [:create_user, :log_in]

    @tag :full_build_only
    test "returns 403 if the logged in user is not a super admin", %{conn: conn} do
      conn = get(conn, "/crm/auth/user/1/usage")
      assert response(conn, 403) == "Not allowed"
    end
  end
end
