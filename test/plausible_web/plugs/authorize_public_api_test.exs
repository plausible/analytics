defmodule PlausibleWeb.Plugs.AuthorizePublicAPITest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Teams.Test

  alias PlausibleWeb.Plugs.AuthorizePublicAPI

  setup %{conn: conn} do
    conn =
      conn
      |> put_private(PlausibleWeb.FirstLaunchPlug, :skip)
      |> bypass_through(PlausibleWeb.Router)

    {:ok, conn: conn}
  end

  test "halts with error when bearer token is missing", %{conn: conn} do
    conn =
      conn
      |> get("/")
      |> assign(:api_scope, "stats:read:*")
      |> AuthorizePublicAPI.call(nil)

    assert conn.halted
    assert json_response(conn, 401)["error"] =~ "Missing API key."
  end

  test "halts with error when bearer token is invalid against read-only Stats API", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer invalid")
      |> get("/")
      |> assign(:api_scope, "stats:read:*")
      |> AuthorizePublicAPI.call(nil)

    assert conn.halted
    assert json_response(conn, 401)["error"] =~ "Invalid API key or site ID."
  end

  test "halts with error when bearer token is invalid", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer invalid")
      |> get("/")
      |> assign(:api_scope, "sites:provision:*")
      |> AuthorizePublicAPI.call(nil)

    assert conn.halted
    assert json_response(conn, 401)["error"] =~ "Invalid API key."
  end

  test "halts with error on missing site ID when request made to Stats API", %{conn: conn} do
    api_key = insert(:api_key, user: build(:user))

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{api_key.key}")
      |> get("/")
      |> assign(:api_scope, "stats:read:*")
      |> AuthorizePublicAPI.call(nil)

    assert conn.halted
    assert json_response(conn, 400)["error"] =~ "Missing site ID."
  end

  @tag :ee_only
  test "halts with error when upgrade is required", %{conn: conn} do
    user = new_user() |> subscribe_to_enterprise_plan(paddle_plan_id: "123321", features: [])
    site = new_site(owner: user)
    api_key = insert(:api_key, user: user)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{api_key.key}")
      |> get("/", %{"site_id" => site.domain})
      |> assign(:api_scope, "stats:read:*")
      |> AuthorizePublicAPI.call(nil)

    assert conn.halted

    assert json_response(conn, 402)["error"] =~
             "The account that owns this API key does not have access"
  end

  test "halts with error when site is locked", %{conn: conn} do
    user = new_user()
    site = new_site(owner: user, locked: true)
    api_key = insert(:api_key, user: user)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{api_key.key}")
      |> get("/", %{"site_id" => site.domain})
      |> assign(:api_scope, "stats:read:*")
      |> AuthorizePublicAPI.call(nil)

    assert conn.halted
    assert json_response(conn, 402)["error"] =~ "This Plausible site is locked"
  end

  test "halts with error when site ID is invalid", %{conn: conn} do
    user = new_user(trial_expiry_date: Date.utc_today())
    _site = new_site(owner: user)
    api_key = insert(:api_key, user: user)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{api_key.key}")
      |> get("/", %{"site_id" => "invalid.domain"})
      |> assign(:api_scope, "stats:read:*")
      |> AuthorizePublicAPI.call(nil)

    assert conn.halted
    assert json_response(conn, 401)["error"] =~ "Invalid API key or site ID."
  end

  test "halts with error when API key owner does not have access to the requested site", %{
    conn: conn
  } do
    user = new_user(trial_expiry_date: Date.utc_today())
    site = new_site()
    api_key = insert(:api_key, user: user)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{api_key.key}")
      |> get("/", %{"site_id" => site.domain})
      |> assign(:api_scope, "stats:read:*")
      |> AuthorizePublicAPI.call(nil)

    assert conn.halted
    assert json_response(conn, 401)["error"] =~ "Invalid API key or site ID."
  end

  test "halts with error when API lacks required scope", %{conn: conn} do
    user = insert(:user)
    api_key = insert(:api_key, user: user)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{api_key.key}")
      |> get("/")
      |> assign(:api_scope, "sites:provision:*")
      |> AuthorizePublicAPI.call(nil)

    assert conn.halted
    assert json_response(conn, 401)["error"] =~ "Invalid API key."
  end

  test "halts with error when API rate limit hit", %{conn: conn} do
    user = insert(:user)
    api_key = insert(:api_key, user: user, hourly_request_limit: 1)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{api_key.key}")
      |> get("/")
      |> assign(:api_scope, "sites:read:*")

    first_resp = AuthorizePublicAPI.call(conn, nil)
    second_resp = AuthorizePublicAPI.call(conn, nil)

    refute first_resp.halted
    assert second_resp.halted
    assert json_response(second_resp, 429)["error"] =~ "Too many API requests."
  end

  test "passes and sets current user when valid API key with required scope provided", %{
    conn: conn
  } do
    user = insert(:user)
    api_key = insert(:api_key, user: user, scopes: ["sites:provision:*"])

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{api_key.key}")
      |> get("/")
      |> assign(:api_scope, "sites:provision:*")
      |> AuthorizePublicAPI.call(nil)

    refute conn.halted
    assert conn.assigns.current_user.id == user.id
  end

  test "passes and sets current user and site when valid API key and site ID provided", %{
    conn: conn
  } do
    user = new_user()
    site = new_site(owner: user)
    api_key = insert(:api_key, user: user)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{api_key.key}")
      |> get("/", %{"site_id" => site.domain})
      |> assign(:api_scope, "stats:read:*")
      |> AuthorizePublicAPI.call(nil)

    refute conn.halted
    assert conn.assigns.current_user.id == user.id
    assert conn.assigns.site.id == site.id
  end

  @tag :ee_only
  test "passes for super admin user even if not a member of the requested site", %{conn: conn} do
    user = new_user()
    patch_env(:super_admin_user_ids, [user.id])
    site = new_site(locked: true)
    api_key = insert(:api_key, user: user)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{api_key.key}")
      |> get("/", %{"site_id" => site.domain})
      |> assign(:api_scope, "stats:read:*")
      |> AuthorizePublicAPI.call(nil)

    refute conn.halted
    assert conn.assigns.current_user.id == user.id
    assert conn.assigns.site.id == site.id
  end

  test "passes for subscope match", %{conn: conn} do
    user = insert(:user)
    api_key = insert(:api_key, user: user, scopes: ["funnels:*"])

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{api_key.key}")
      |> get("/")
      |> assign(:api_scope, "funnels:read:*")
      |> AuthorizePublicAPI.call(nil)

    refute conn.halted
    assert conn.assigns.current_user.id == user.id
  end
end
