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
      |> with_api_key("Bad key")
      |> get("/api/v1/stats/aggregate", %{"site_id" => "some-site.com", "metrics" => "pageviews"})

    assert json_response(conn, 401) == %{
             "error" =>
               "Invalid API key or site ID. Please make sure you're using a valid API key with access to the site you've requested."
           }
  end

  test "good API key but bad site id - returns 401", %{conn: conn, api_key: api_key} do
    conn =
      conn
      |> with_api_key(api_key)
      |> get("/api/v1/stats/aggregate", %{"site_id" => "some-site.com", "metrics" => "pageviews"})

    assert json_response(conn, 401) == %{
             "error" =>
               "Invalid API key or site ID. Please make sure you're using a valid API key with access to the site you've requested."
           }
  end

  test "good API key but missing site id - returns 400", %{conn: conn, api_key: api_key} do
    conn =
      conn
      |> with_api_key(api_key)
      |> get("/api/v1/stats/aggregate", %{"metrics" => "pageviews"})

    assert json_response(conn, 400) == %{
             "error" =>
               "Missing site ID. Please provide the required site_id parameter with your request."
           }
  end

  test "locked site - returns 402", %{conn: conn, api_key: api_key, user: user} do
    site = insert(:site, members: [user])
    {1, _} = Plausible.Billing.SiteLocker.set_lock_status_for(user, true)

    conn =
      conn
      |> with_api_key(api_key)
      |> get("/api/v1/stats/aggregate", %{"site_id" => site.domain, "metrics" => "pageviews"})

    assert %{"error" => error} = json_response(conn, 402)
    assert error =~ "missing active subscription"
  end

  test "can access with correct API key and site ID", %{conn: conn, user: user, api_key: api_key} do
    site = insert(:site, members: [user])

    conn =
      conn
      |> with_api_key(api_key)
      |> get("/api/v1/stats/aggregate", %{"site_id" => site.domain, "metrics" => "pageviews"})

    assert json_response(conn, 200) == %{
             "results" => %{"pageviews" => %{"value" => 0}}
           }
  end

  test "can access as an admin", %{conn: conn, user: user, api_key: api_key} do
    Application.put_env(:plausible, :super_admin_user_ids, [user.id])
    site = insert(:site)

    conn =
      conn
      |> with_api_key(api_key)
      |> get("/api/v1/stats/aggregate", %{"site_id" => site.domain, "metrics" => "pageviews"})

    assert json_response(conn, 200) == %{
             "results" => %{"pageviews" => %{"value" => 0}}
           }
  end

  test "limits the rate of API requests", %{user: user} do
    api_key = insert(:api_key, user_id: user.id, hourly_request_limit: 3)

    build_conn()
    |> with_api_key(api_key.key)
    |> get("/api/v1/stats/aggregate")

    build_conn()
    |> with_api_key(api_key.key)
    |> get("/api/v1/stats/aggregate")

    build_conn()
    |> with_api_key(api_key.key)
    |> get("/api/v1/stats/aggregate")

    conn =
      build_conn()
      |> with_api_key(api_key.key)
      |> get("/api/v1/stats/aggregate")

    assert json_response(conn, 429) == %{
             "error" => "Too many API requests. Your API key is limited to 3 requests per hour."
           }
  end

  defp with_api_key(conn, api_key) do
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key}")
  end
end
