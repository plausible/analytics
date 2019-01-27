defmodule PlausibleWeb.PageControllerTest do
  use PlausibleWeb.ConnCase

  describe "GET /" do
    test "shows the landing page", %{conn: conn} do
      conn = get(conn, "/")
      assert html_response(conn, 200) =~ "Plausible"
    end
  end
end
