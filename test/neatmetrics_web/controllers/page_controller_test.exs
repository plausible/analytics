defmodule NeatmetricsWeb.PageControllerTest do
  use NeatmetricsWeb.ConnCase

  describe "GET /" do
    test "shows the landing page", %{conn: conn} do
      conn = get(conn, "/")
      assert html_response(conn, 200) =~ "neatmetrics"
    end
  end
end
