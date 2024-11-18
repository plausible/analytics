defmodule PlausibleWeb.Api.ExternalStatsController.AuthTest do
  use PlausibleWeb.ConnCase
  use Plausible.Teams.Test

  setup [:create_user, :create_api_key]

  test "unauthenticated request - returns 401", %{conn: conn} do
    conn
    |> get("/api/v1/stats/aggregate", %{
      "site_id" => "some-site.com",
      "metrics" => "pageviews"
    })
    |> assert_error(
      401,
      "Missing API key. Please use a valid Plausible API key as a Bearer Token."
    )
  end

  test "bad API key - returns 401", %{conn: conn} do
    conn
    |> with_api_key("Bad key")
    |> get("/api/v1/stats/aggregate", %{"site_id" => "some-site.com", "metrics" => "pageviews"})
    |> assert_error(
      401,
      "Invalid API key or site ID. Please make sure you're using a valid API key with access to the site you've requested."
    )
  end

  test "good API key but bad site id - returns 401", %{conn: conn, api_key: api_key} do
    conn
    |> with_api_key(api_key)
    |> get("/api/v1/stats/aggregate", %{"site_id" => "some-site.com", "metrics" => "pageviews"})
    |> assert_error(
      401,
      "Invalid API key or site ID. Please make sure you're using a valid API key with access to the site you've requested."
    )
  end

  test "good API key but missing site id - returns 400", %{conn: conn, api_key: api_key} do
    conn
    |> with_api_key(api_key)
    |> get("/api/v1/stats/aggregate", %{"metrics" => "pageviews"})
    |> assert_error(
      400,
      "Missing site ID. Please provide the required site_id parameter with your request."
    )
  end

  test "locked site - returns 402", %{conn: conn, api_key: api_key, user: user} do
    site = insert(:site, members: [user])
    {:ok, 1} = Plausible.Billing.SiteLocker.set_lock_status_for(user, true)

    conn
    |> with_api_key(api_key)
    |> get("/api/v1/stats/aggregate", %{"site_id" => site.domain, "metrics" => "pageviews"})
    |> assert_error(402, "missing active subscription")
  end

  test "can access with correct API key and site ID", %{conn: conn, user: user, api_key: api_key} do
    site = insert(:site, members: [user])

    conn
    |> with_api_key(api_key)
    |> get("/api/v1/stats/aggregate", %{"site_id" => site.domain, "metrics" => "pageviews"})
    |> assert_ok(%{
      "results" => %{"pageviews" => %{"value" => 0}}
    })
  end

  describe "super admin access" do
    @describetag :ee_only
    setup %{user: user} do
      patch_env(:super_admin_user_ids, [user.id])
    end

    test "can access as a super admin", %{conn: conn, api_key: api_key} do
      site = insert(:site)

      conn
      |> with_api_key(api_key)
      |> get("/api/v1/stats/aggregate", %{"site_id" => site.domain, "metrics" => "pageviews"})
      |> assert_ok(%{
        "results" => %{"pageviews" => %{"value" => 0}}
      })
    end

    test "can access as a super admin even if site is locked", %{
      conn: conn,
      api_key: api_key,
      user: user
    } do
      site = insert(:site, members: [user])
      {:ok, 1} = Plausible.Billing.SiteLocker.set_lock_status_for(user, true)

      conn
      |> with_api_key(api_key)
      |> get("/api/v1/stats/aggregate", %{"site_id" => site.domain, "metrics" => "pageviews"})
      |> assert_ok(%{
        "results" => %{"pageviews" => %{"value" => 0}}
      })
    end
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

    build_conn()
    |> with_api_key(api_key.key)
    |> get("/api/v1/stats/aggregate")
    |> assert_error(
      429,
      "Too many API requests. Your API key is limited to 3 requests per hour."
    )
  end

  test "can access with either site_id after domain change", %{
    conn: conn,
    user: user,
    api_key: api_key
  } do
    old_domain = "old.example.com"
    new_domain = "new.example.com"
    site = insert(:site, domain: old_domain, members: [user])

    Plausible.Site.Domain.change(site, new_domain)

    conn
    |> with_api_key(api_key)
    |> get("/api/v1/stats/aggregate", %{"site_id" => new_domain, "metrics" => "pageviews"})
    |> assert_ok(%{
      "results" => %{"pageviews" => %{"value" => 0}}
    })

    conn
    |> with_api_key(api_key)
    |> get("/api/v1/stats/aggregate", %{"site_id" => old_domain, "metrics" => "pageviews"})
    |> assert_ok(%{
      "results" => %{"pageviews" => %{"value" => 0}}
    })
  end

  @tag :ee_only
  test "returns HTTP 402 when user is on a growth plan", %{
    conn: conn,
    user: user,
    api_key: api_key
  } do
    subscribe_to_growth_plan(user)
    site = new_site(owner: user)

    conn
    |> with_api_key(api_key)
    |> get("/api/v1/stats/aggregate", %{"site_id" => site.domain, "metrics" => "pageviews"})
    |> assert_error(
      402,
      "The account that owns this API key does not have access to Stats API."
    )
  end

  defp with_api_key(conn, api_key) do
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key}")
  end

  defp assert_error(conn, status, message) do
    assert json_response(conn, status)["error"] =~ message
  end

  defp assert_ok(conn, payload) do
    assert json_response(conn, 200) == payload
  end
end
