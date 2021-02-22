defmodule PlausibleWeb.Api.ExternalStatsController.AuthTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  setup [:create_user, :create_api_key]

  test "unauthenticated request - returns 401", %{conn: conn} do
    conn =
      get(conn, "/api/v1/stats/aggregate", %{
        "site_id" => "some-site.com",
        "metrics" => "pageviews"
      })

    assert json_response(conn, 401) == %{
             "error" => "Missing API key. Please use a valid Plausible API key as a Bearer Token."
           }
  end

  test "bad API key - returns 401", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer bad-key")
      |> get("/api/v1/stats/aggregate", %{"site_id" => "some-site.com", "metrics" => "pageviews"})

    assert json_response(conn, 401) == %{
             "error" =>
               "Invalid API key or site ID. Please make sure you're using a valid API key with access to the site you've requested."
           }
  end

  test "good API key but bad site id - returns 401", %{conn: conn, api_key: api_key} do
    conn =
      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key}")
      |> get("/api/v1/stats/aggregate", %{"site_id" => "some-site.com", "metrics" => "pageviews"})

    assert json_response(conn, 401) == %{
             "error" =>
               "Invalid API key or site ID. Please make sure you're using a valid API key with access to the site you've requested."
           }
  end

  test "good API key but missing site id - returns 400", %{conn: conn, api_key: api_key} do
    conn =
      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key}")
      |> get("/api/v1/stats/aggregate", %{"metrics" => "pageviews"})

    assert json_response(conn, 400) == %{
             "error" =>
               "Missing site ID. Please provide the required site_id parameter with your request."
           }
  end
end
