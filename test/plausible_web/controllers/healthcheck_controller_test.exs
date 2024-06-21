defmodule PlausibleWeb.HealthcheckControllerTest do
  use PlausibleWeb.ConnCase

  test "GET /health_check", %{conn: conn} do
    conn = get(conn, "/health_check")

    %{"name" => "plausible", "timestamp" => _, "status" => "RUNNING", "version" => _} =
      json_response(conn, 200)
  end
end
