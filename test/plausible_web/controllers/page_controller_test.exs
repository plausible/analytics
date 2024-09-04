defmodule PlausibleWeb.PageControllerTest do
  use PlausibleWeb.ConnCase, async: true

  setup {PlausibleWeb.FirstLaunchPlug.Test, :skip}

  describe "GET /" do
    setup [:create_user, :log_in]

    test "shows landing page when user not authenticated" do
      assert build_conn() |> get("/") |> html_response(200) =~ "Welcome to Plausible!"
    end

    test "redirects to /sites if user is authenticated", %{conn: conn} do
      assert conn
             |> get("/")
             |> redirected_to(302) == "/sites"
    end
  end
end
