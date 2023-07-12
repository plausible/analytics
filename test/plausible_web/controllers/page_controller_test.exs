defmodule PlausibleWeb.PageControllerTest do
  use PlausibleWeb.ConnCase, async: true

  describe "GET /" do
    test "shows landing page when user not authenticated", %{conn: conn} do
      assert conn |> get("/") |> html_response(200) =~ "Welcome to Plausible Analytics!"
    end

    test "redirects to /sites if user is authenticated", %{conn: conn} do
      user = insert(:user)

      assert conn
             |> init_test_session(%{current_user_id: user.id})
             |> get("/")
             |> redirected_to(302) == "/sites"
    end
  end
end
