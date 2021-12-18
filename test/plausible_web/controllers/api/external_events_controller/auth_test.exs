defmodule PlausibleWeb.Api.ExternalSitesController.AuthTest do
  use PlausibleWeb.ConnCase
  use Plausible.Repo

  setup %{conn: conn} do
    user = insert(:user)
    api_key = insert(:api_key, user: user, scopes: ["events:read:*"])
    conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key.key}")
    {:ok, user: user, api_key: api_key, conn: conn}
  end

  describe "POST /api/v1/events" do
    test "cannot access with a bad API key scope", %{conn: conn, user: user} do
      api_key = insert(:api_key, user: user, scopes: ["stats:read:*"])

      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key.key}")
        |> get("/api/v1/events", %{"site_id" => "some-site.com"})

      assert json_response(conn, 401) == %{
               "error" =>
                 "Invalid API key or site ID. Please make sure you're using a valid API key with access to the site you've requested."
             }
    end

    test "unauthenticated request - returns 401", %{conn: conn} do
      conn = get(conn, "/api/v1/events", %{"site_id" => "some-site.com"})

      assert json_response(conn, 401) == %{
               "error" =>
                 "Invalid API key or site ID. Please make sure you're using a valid API key with access to the site you've requested."
             }
    end

    test "bad API key - returns 401", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", "Bearer bad-key")
        |> get("/api/v1/events", %{"site_id" => "some-site.com"})

      assert json_response(conn, 401) == %{
               "error" =>
                 "Invalid API key or site ID. Please make sure you're using a valid API key with access to the site you've requested."
             }
    end

    test "good API key but bad site id - returns 401", %{conn: conn} do
      conn =
        conn
        |> get("/api/v1/events", %{"site_id" => "some-site.com"})

      assert json_response(conn, 401) == %{
               "error" =>
                 "Invalid API key or site ID. Please make sure you're using a valid API key with access to the site you've requested."
             }
    end

    test "good API key but missing site id - returns 400", %{conn: conn} do
      conn =
        conn
        |> get("/api/v1/events", %{})

      assert json_response(conn, 400) == %{
               "error" =>
                 "Missing site ID. Please provide the required site_id parameter with your request."
             }
    end

    test "can access with correct API key and site ID", %{conn: conn, user: user} do
      site = insert(:site, members: [user])
      event = insert(:goal, %{domain: site.domain, event_name: "404"})

      conn =
        conn
        |> get("/api/v1/events", %{"site_id" => site.domain})

      assert json_response(conn, 200) == [
               %{"event_type" => "custom", "id" => event.id, "name" => "404", "props" => []}
             ]
    end

    test "can access as an admin", %{conn: conn, user: user} do
      Application.put_env(:plausible, :admin_user_ids, [user.id])
      site = insert(:site)
      event = insert(:goal, %{domain: site.domain, event_name: "404"})

      conn =
        conn
        |> get("/api/v1/events", %{"site_id" => site.domain})

      assert json_response(conn, 200) == [
               %{"event_type" => "custom", "id" => event.id, "name" => "404", "props" => []}
             ]
    end

    test "limits the rate of API requests", %{user: user} do
      api_key = insert(:api_key, user_id: user.id, hourly_request_limit: 3)

      build_conn()
      |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key.key}")
      |> get("/api/v1/events")

      build_conn()
      |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key.key}")
      |> get("/api/v1/events")

      build_conn()
      |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key.key}")
      |> get("/api/v1/events")

      conn =
        build_conn()
        |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key.key}")
        |> get("/api/v1/events")

      assert json_response(conn, 429) == %{
               "error" => "Too many API requests. Your API key is limited to 3 requests per hour."
             }
    end
  end

  describe "POST /api/v1/events/:event_id/properties" do
    test "cannot access with a bad API key scope", %{conn: conn, user: user} do
      api_key = insert(:api_key, user: user, scopes: ["stats:read:*"])

      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key.key}")
        |> get("/api/v1/events/1/properties", %{"site_id" => "some-site.com"})

      assert json_response(conn, 401) == %{
               "error" =>
                 "Invalid API key or site ID. Please make sure you're using a valid API key with access to the site you've requested."
             }
    end

    test "unauthenticated request - returns 401", %{conn: conn} do
      conn = get(conn, "/api/v1/events/1/properties", %{"site_id" => "some-site.com"})

      assert json_response(conn, 401) == %{
               "error" =>
                 "Invalid API key or site ID. Please make sure you're using a valid API key with access to the site you've requested."
             }
    end

    test "bad API key - returns 401", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", "Bearer bad-key")
        |> get("/api/v1/events/1/properties", %{"site_id" => "some-site.com"})

      assert json_response(conn, 401) == %{
               "error" =>
                 "Invalid API key or site ID. Please make sure you're using a valid API key with access to the site you've requested."
             }
    end

    test "good API key but bad site id - returns 401", %{conn: conn} do
      conn =
        conn
        |> get("/api/v1/events/1/properties", %{"site_id" => "some-site.com"})

      assert json_response(conn, 401) == %{
               "error" =>
                 "Invalid API key or site ID. Please make sure you're using a valid API key with access to the site you've requested."
             }
    end

    test "good API key but missing site id - returns 400", %{conn: conn} do
      conn =
        conn
        |> get("/api/v1/events/1/properties", %{})

      assert json_response(conn, 400) == %{
               "error" =>
                 "Missing site ID. Please provide the required site_id parameter with your request."
             }
    end

    test "can access with correct API key and site ID", %{conn: conn, user: user} do
      site = insert(:site, members: [user])
      event = insert(:goal, %{domain: site.domain, event_name: "404"})

      conn =
        conn
        |> get("/api/v1/events/#{event.id}/properties", %{"site_id" => site.domain})

      assert json_response(conn, 200) == []
    end

    test "can access as an admin", %{conn: conn, user: user} do
      Application.put_env(:plausible, :admin_user_ids, [user.id])
      site = insert(:site)
      event = insert(:goal, %{domain: site.domain, event_name: "404"})

      conn =
        conn
        |> get("/api/v1/events/#{event.id}/properties", %{"site_id" => site.domain})

      assert json_response(conn, 200) == []
    end

    test "limits the rate of API requests", %{user: user} do
      api_key = insert(:api_key, user_id: user.id, hourly_request_limit: 3)

      build_conn()
      |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key.key}")
      |> get("/api/v1/events/1/properties")

      build_conn()
      |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key.key}")
      |> get("/api/v1/events/1/properties")

      build_conn()
      |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key.key}")
      |> get("/api/v1/events/1/properties")

      conn =
        build_conn()
        |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key.key}")
        |> get("/api/v1/events/1/properties")

      assert json_response(conn, 429) == %{
               "error" => "Too many API requests. Your API key is limited to 3 requests per hour."
             }
    end
  end
end
